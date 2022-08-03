# flutter_webrtc_websocket

Demonstration of flutter webRTC and websocket implementation.

For WebRTC, I use [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) and for websocket [web_socket_channel](https://pub.dev/packages/web_socket_channel) is used.

For server websocket, I use nodejs with [ws](https://github.com/websockets/ws) library.

## Server code

To make your own server run this code with `nodejs`. It create a websocket server in port 8080.

```js
import { WebSocket, WebSocketServer } from "ws";

const wss = new WebSocketServer({ port: 8080 });

wss.on("connection", (ws) => {
  ws.send('{"event":"connection","data":"connected"}');
  ws.on("message", (data, isbinary) => {
    // Broadcasting to other client except sender
    wss.clients.forEach((client) => {
      if (client != ws && client.readyState == WebSocket.OPEN) {
        client.send(data, { binary: false });
      }
    });
  });
});
```

Read [this article]() to get a good grasp about working of the code.

> **Warning**: I haven't added android and IOS specific code. So this app runs only on web. Please add android persmissions in `android-menifest.xml` file. For more, please see the `flutter_webrtc` getting started guide.
