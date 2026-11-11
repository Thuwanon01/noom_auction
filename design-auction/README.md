# Design — Noom Auction (Minimal theme)

Design canvas: https://claude.ai/artifact/CA6c1dM9meMzeiUNgJubR3

> Link เป็น private เปิดได้เฉพาะเจ้าของ ถ้าจะให้คนอื่นดูต้องกด Share ในหน้า artifact

## Boards

| File | หน้า |
|---|---|
| `Main.dc.html` | Design System (สี, ฟอนต์, ระยะ, component) |
| `EventList.dc.html` | รายการ Event |
| `AuctionDetail.dc.html` | รายละเอียด + เสนอราคา + ประวัติการประมูล |
| `CreateEvent.dc.html` | สร้าง Event |
| `RegisterProduct.dc.html` | ลงทะเบียนสินค้า |
| `Login.dc.html` / `Register.dc.html` | เข้าสู่ระบบ / สมัครสมาชิก |

`canvas.json` คือ layout ของ canvas (ตำแหน่ง artboard)

## Minimal theme

ขาว ดำ เส้นบาง 1px ไม่มีเงา ไม่มี gradient, ฟอนต์ Kanit, radius 6px, สีเน้นสีเดียวคือ `#111`
(เขียว/ส้ม/แดงใช้เฉพาะสถานะ live / upcoming / urgent)

โค้ดที่ implement จริงอยู่ใน `auction/` (`app/assets/stylesheets/design_system.css`, หน้าตัวอย่างที่ `/design`)
