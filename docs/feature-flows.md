# majoin — ฟีเจอร์แต่ละแบบ ทำงานยังไง ใช้ component ไหน

## Component ทั้งหมด

| Component | บทบาท |
|-----------|-------|
| Flutter client | แอปผู้ใช้ (`client/`) |
| Synapse | Matrix homeserver — เก็บ event, room, ส่งต่อข้อความ |
| Caddy | reverse proxy หน้าด่าน, route โดเมน |
| coturn | TURN/STUN server — เจาะ NAT สำหรับ 1:1 call |
| LiveKit SFU | media server group call — forward stream |
| lk-jwt-service | แลก Matrix OpenID token เป็น LiveKit JWT |
| sygnal | push gateway — ส่ง notif ไป FCM/APNs |
| majoin API | FastAPI (`services/majoin`) — sticker store + user directory, port 8410 |
| weather-bot | Matrix bot (matrix-nio) — demo |

## ฟีเจอร์ × การทำงาน × component

| ฟีเจอร์ | ทำงานยังไง | Component ที่เกี่ยว |
|---------|------------|---------------------|
| **Text chat** | client ส่ง `m.room.message` event → Synapse เก็บ + sync ไปสมาชิกอื่น. E2EE ผ่าน Olm/Megolm | Client, Synapse, Caddy |
| **Media / file** | client อัปโหลดไฟล์เข้า Synapse media repo → ได้ `mxc://` URI → ส่งใน message event. ผู้รับดึงไฟล์จาก media repo | Client, Synapse, Caddy |
| **Sticker** | client ดึงรายการ sticker จาก majoin API (`/api/stickers/*`) → ส่งเป็น `m.sticker` event ผ่าน Synapse | Client, majoin API, Synapse, Caddy |
| **1:1 call** | signalling (`m.call.*` event) ผ่าน Synapse. media เป็น **P2P WebRTC** ตรงระหว่าง 2 client. coturn relay เฉพาะตอนเจาะ NAT ไม่ได้ | Client, Synapse, coturn |
| **Group call** | membership = `m.call.member` state ผ่าน Synapse. client แลก token ที่ `/sfu/get` → media วิ่งผ่าน **LiveKit SFU** (E2EE, SFU แค่ forward) | Client, Synapse, lk-jwt-service, LiveKit SFU, Caddy |
| **Push notif** | Synapse ตรวจ event ที่ต้องเตือน → ยิงไป sygnal → sygnal ส่งต่อ FCM (Android) / APnS (iOS) → client | Synapse, sygnal, FCM/APNs |
| **User directory** | client query รายชื่อผู้ใช้ผ่าน majoin API endpoint | Client, majoin API, Caddy |
| **Bot (weather)** | login เป็น user ปกติ, sync event จาก Synapse, react ตอบกลับเป็น message event | weather-bot, Synapse |

## ข้อสังเกต

- **Synapse แตะแทบทุกฟีเจอร์** — เป็นแกนกลาง signalling + storage. ยกเว้น
  media path ของ call (1:1 P2P, group ผ่าน SFU) ที่ไม่วิ่งผ่าน Synapse
- **Caddy หน้าด่านทุก HTTP/WS** — แต่ media RTC (UDP/TCP) วิ่งตรงเข้า host
  ไม่ผ่าน Caddy
- **call media ไม่ผ่าน server กลางเสมอ** — 1:1 ตรง P2P, group ผ่าน SFU
  ที่ forward อย่างเดียว ไม่ decode
- **majoin API แยกขาดจาก Matrix** — REST ปกติ, ใช้กับ sticker + user directory
