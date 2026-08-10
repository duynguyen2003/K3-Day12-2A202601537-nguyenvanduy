# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Văn Duy  Mã học viên: 2A202601537

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu để mặc định "changeme", khi deploy lên cloud mà quên set biến môi trường, app vẫn khởi động và báo health check OK (200). Load balancer sẽ đưa traffic vào, nhưng mọi request tới `/ask` sẽ dùng key "changeme" và bị lỗi 401 từ OpenAI, gây lỗi cho người dùng. Việc "chết sớm" (fail fast) giúp quá trình deploy thất bại ngay lập tức, load balancer không đẩy traffic vào bản lỗi, bảo vệ người dùng và báo động cho mình biết ngay là quên cấu hình.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

`{"timestamp": "2026-08-10T04:30:00.000000Z", "level": "info", "event": "ask_request_completed", "user_id": "sv-test", "duration_ms": 120, "cost": 0.05}`
Hai việc làm được:
1. Đưa log vào các hệ thống như Elasticsearch/Datadog để vẽ biểu đồ thống kê tổng chi phí (cost) theo từng `user_id` hoặc tính p99 cho `duration_ms`.
2. Dễ dàng query/filter tự động bằng các công cụ như `jq` (ví dụ: tìm tất cả request có `duration_ms > 1000`) mà không cần viết regex phức tạp để parse text.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1000 MB |
| Multi-stage | ~150 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần chênh lệch là do hệ điều hành đầy đủ, các công cụ build (gcc, make), pip cache, và source code rác. Multi-stage build chỉ copy đúng thư mục `site-packages` đã compile xong và code chạy sang một image cực gọn (`slim` hoặc `alpine`), vứt bỏ hoàn toàn môi trường build nặng nề.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Những layer được dùng lại (cache): Từ đầu đến hết lệnh `RUN pip install -r requirements.txt`.
- Những layer phải chạy lại: Từ lệnh `COPY . .` trở xuống (do nội dung code thay đổi).
Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi lần sửa code nhỏ (như `main.py`), layer `COPY . .` sẽ bị mất cache, kéo theo lệnh `RUN pip install` cũng phải chạy lại toàn bộ, cực kỳ tốn thời gian tải và cài thư viện dù file `requirements.txt` không hề thay đổi.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: Kẻ tấn công khai thác lỗ hổng (như RCE) để chạy shell trong container -> Vì app chạy bằng root, shell đó có quyền root trong container -> Nếu cấu hình lỏng lẻo (vd: rò rỉ mount thư mục host), kẻ gian có thể dùng quyền root này để sửa file trên máy host, chiếm quyền máy chủ.
Lệnh `USER appuser` cắt đứt ngay bước đầu tiên: dù chiếm được shell, shell đó chỉ mang quyền user thường, không thể cài thêm phần mềm độc hại, đổi cấu hình hay leo thang đặc quyền dễ dàng.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa 20 request.
Giải thích: Người dùng có thể gửi 10 request vào giây 59 của phút trước, và gửi tiếp 10 request vào giây 01 của phút hiện tại. Hệ thống reset vào giây 00 nên chỉ đếm 10 request cho mỗi cửa sổ phút riêng biệt, dẫn đến họ lách luật gửi được 20 request trong 2 giây. Sliding window giải quyết triệt để lỗi này bằng cách nhìn lùi về đúng 60 giây.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác biệt: Rate limit đếm số **lần** gọi trong một **khoảng thời gian ngắn** (phút) để chống spam/DDoS. Cost guard cộng dồn **chi phí tiền tệ** trong một **khoảng thời gian dài** (tháng) để chống hết ngân sách.
- **Rate limit qua, Cost guard chặn:** User gọi rất chậm (10 lần/ngày) nhưng câu hỏi rất dài tốn nhiều token, cuối tháng tổng tiền vượt $10. Rate limit không thấy spam, nhưng Cost guard sẽ chặn.
- **Cost guard qua, Rate limit chặn:** User vừa nạp tiền đầu tháng, budget đầy đủ, nhưng cắm auto gửi 20 request trong 1 giây. Cost guard chưa vượt ngân sách, nhưng Rate limit sẽ chặn lại ngay vì spam.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis mất kết nối.
2. Hệ thống Load Balancer / Kubernetes gọi `/health` (đã gộp) và nhận lỗi 503 vì không nối được Redis.
3. Nó tưởng rằng bản thân app (container) bị treo (chết) nên ra lệnh kill và restart cả 3 container.
4. Container mới lên vẫn chưa kết nối được Redis, lại bị kill -> Tạo ra vòng lặp crash liên tục (CrashLoopBackOff). Toàn bộ hệ thống sụp đổ không cần thiết.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Số `history_length` sẽ nhảy lộn xộn, mất tính liên tục (ví dụ: 1, 1, 2, 1, 3, 2...). Lý do là Load Balancer phân phát request ngẫu nhiên vào 1 trong 3 container. Nếu dùng dict RAM, mỗi container giữ một cuốn sổ ghi chép độc lập, nên user sẽ thấy bot lúc nhớ lúc quên. Lưu ở Redis giúp gom chung sổ ghi chép, ai đọc cũng thấy cùng 1 số lượng lịch sử tăng đều.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi: "Port already in use" hoặc "Health check timeout" khi deploy lên Render.
Nguyên nhân: Mặc định Render cấp phát tự động một port và nhồi vào biến `$PORT`. Trong file `main.py` của mình trước đó lỡ hardcode `port=8000`, khiến Render báo timeout vì app không listen đúng port nó yêu cầu.
Cách sửa: Đọc log trên dashboard của Render, sau đó đổi cấu hình bind port thành: `port=int(os.environ.get("PORT", 8000))` để ưu tiên biến môi trường.
