# LiveKit SFU — สรุปสำหรับ majoin

## SFU คืออะไร

**SFU = Selective Forwarding Unit** — media server กลางสำหรับ WebRTC.
ทุก client อัปโหลด stream ครั้งเดียวขึ้น SFU, SFU **ไม่ decode/encode** แค่
forward packet ต่อให้ผู้รับ. ภาระอยู่ที่ bandwidth ไม่ใช่ CPU server.

| โหมด | วิธี | ปัญหา |
|------|------|-------|
| Mesh (P2P) | ทุกคนส่งตรงถึงทุกคน | อัปโหลดระเบิดที่ ~4-5 คน |
| MCU | server รวม stream เป็นภาพเดียว | CPU server หนัก, layout ตายตัว |
| **SFU** | server forward stream ต่อ | ดีสุดสำหรับ scale ← majoin ใช้ตัวนี้ |

## majoin ใช้ยังไง

Group call ใช้ **MatrixRTC** (call membership เป็น Matrix state) + **LiveKit
SFU** routing media. 1:1 call ไม่แตะ LiveKit — ยังเป็น P2P WebRTC + coturn.

2 infra service ใหม่:

- `livekit` — SFU. forward media, ไม่เห็น plaintext (frame E2EE โดย client)
- `lk-jwt-service` — แลก Matrix OpenID token เป็น LiveKit JWT อายุสั้น.
  client เรียกที่ `/sfu/get`

## Traffic flow

### 1:1 call → P2P

```
Client A ──WebRTC──> Client B
            └─ติด NAT─> coturn (TURN relay) ─┘
```

สายตรง peer-to-peer. coturn ช่วยเฉพาะตอนเจาะ NAT ไม่ได้.

### Group call → LiveKit SFU

```
                  ┌─ signalling/state ──> Synapse (m.call.member state)
Client ───────────┤
                  ├─ POST /sfu/get ──> lk-jwt-service ──> Synapse (verify OpenID)
                  │                         └─ คืน {url, jwt}
                  │
                  └─ media (E2EE) ──> LiveKit SFU ──> forward ไป client อื่น
```

## ลำดับเชื่อม group call

1. **Membership** — client `fetchOrCreateGroupCall` (`LiveKitBackend`) →
   publish state `m.call.member` ลง Synapse. ทุกคนเห็นว่าใครอยู่ในสาย
2. **Token exchange** — client POST Matrix OpenID token ไป `/sfu/get` →
   `lk-jwt-service` verify กับ Synapse → คืน LiveKit JWT + URL
3. **Media** — client ต่อ `livekit_client` ไป SFU ด้วย JWT → publish กล้อง/ไมค์
4. **E2EE keys** — กุญแจกระจายผ่าน MatrixRTC (Matrix state) → ป้อนเข้า frame
   cryptor ของ LiveKit

## พอร์ต / โดเมน

| ทาง | ปลายทาง | พอร์ต |
|-----|---------|-------|
| signalling WS | `livekit.tokens2.io` → LiveKit | 7880 (ผ่าน Caddy) |
| token exchange | `livekit.tokens2.io/sfu/get` → lk-jwt | 8080 (ผ่าน Caddy) |
| media RTC | host VPS | UDP 50000-50200, TCP 7881 |
| Matrix state | `chat.tokens2.io` → Synapse | ผ่าน Caddy `/_matrix/*` |

## จุดสำคัญ

- **SFU ไม่เห็น plaintext** — frame E2EE โดย client. LiveKit แค่ forward
- **Synapse = signalling เท่านั้น** สำหรับ group — ใครอยู่สาย, กุญแจ E2EE,
  ผ่าน state event. ไม่แตะ media
- **lk-jwt-service = สะพานสิทธิ์** — แลก identity Matrix ↔ สิทธิ์ LiveKit
- **Caddy** = reverse proxy หน้าด่าน, แยก `/sfu/get` กับ signalling WS
  คนละ backend
- **media RTC ไม่ผ่าน Caddy** — วิ่ง UDP/TCP ตรงเข้า host

