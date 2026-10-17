#!/usr/bin/env python3
"""
Family Messenger — Local Wi-Fi LAN TLS Passthrough Bridge (Windows 11 -> WSL2 Nginx)
Listens on the Windows LAN Wi-Fi IP (192.168.2.122:8443) and forwards raw TLS TCP streams
directly to WSL2 Nginx (127.0.0.1:8443) without terminating or altering TLS.
"""
import asyncio
import socket
import sys


def detect_lan_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("192.168.2.1", 80))
        return s.getsockname()[0]
    except Exception:
        return "192.168.2.122"
    finally:
        s.close()


async def pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def handle_client(
    client_reader: asyncio.StreamReader,
    client_writer: asyncio.StreamWriter,
    target_host: str,
    target_port: int,
) -> None:
    try:
        upstream_reader, upstream_writer = await asyncio.open_connection(
            target_host, target_port
        )
    except Exception:
        client_writer.close()
        return

    await asyncio.gather(
        pipe(client_reader, upstream_writer),
        pipe(upstream_reader, client_writer),
    )


async def main() -> None:
    bind_ip = sys.argv[1] if len(sys.argv) > 1 else detect_lan_ip()
    bind_port = int(sys.argv[2]) if len(sys.argv) > 2 else 8443
    target_host = sys.argv[3] if len(sys.argv) > 3 else "127.0.0.1"
    target_port = int(sys.argv[4]) if len(sys.argv) > 4 else 8443

    server = await asyncio.start_server(
        lambda r, w: handle_client(r, w, target_host, target_port),
        host=bind_ip,
        port=bind_port,
    )
    addrs = ", ".join(str(sock.getsockname()) for sock in server.sockets)
    print(
        f"[FamilyMessenger LAN Bridge] Listening on {addrs} -> {target_host}:{target_port}",
        flush=True,
    )
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
