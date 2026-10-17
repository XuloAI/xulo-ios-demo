# Xulo demo

A sample iOS app for the Xulo SDK. It uses your own panel app. The SDK source is not in this repository.

The Xcode project already depends on the closed package:

```
https://github.com/XuloAI/xulo-ios-sdk
```

Xcode downloads version 0.1.0 or later, up to the next major version.

## Requirements

- Xcode 16 or later
- iOS 15 or later
- An app and an API key from [xulo.io](https://xulo.io)
- A physical iPhone for a real push. The simulator can run the API checks. It does not receive remote notifications.

## Open the project

```bash
git clone https://github.com/XuloAI/xulo-ios-demo.git
cd xulo-ios-demo
open XuloDemo.xcodeproj
```

Two products are already attached:

| Product | Target |
| --- | --- |
| `Xulo` | XuloDemo |
| `XuloExtension` | NotificationService and NotificationContent |

`Xulo` is not linked into either extension.

## Signing

Select your team on XuloDemo, NotificationService, and NotificationContent.

The bundle ids are:

- `app.xulo.demo`
- `app.xulo.demo.NotificationService`
- `app.xulo.demo.NotificationContent`

All three targets share the App Group `group.app.xulo.demo`. The same string is the `XuloAppGroup` value in each Info.plist. The content extension category is `xulo`.

Create an app in the panel with the bundle id `app.xulo.demo`. Add the Apple key when you want the panel to deliver a push.

## Run

Build and run on a phone.

On the first screen, paste the organization API key and tap Start.

Tap Allow push and accept the system prompt. The subscription id on that screen is the device in the panel.

## Checks

Tap Run all checks. The app walks the device API and marks each row Pass or Fail:

- Register, a numeric external id, and a blank external id that does not log the device out
- Log in, tags, and open
- A session posted twice, counted once
- An event, a purchase whose second post replaces the amount, and a refund
- An in-app card request
- A failure report, and a crash report that is refused when it contains an identity
- A local push open
- Log out, which keeps the subscription id

Two rows stay marked Look. The push token needs the permission prompt on a phone. An image push is sent from the panel to that subscription id.

## Send a push

In the panel, send a message to this device.

An image push sets `mutable-content` and `att.id`. The notification service extension downloads the image. If the download fails, or time runs out, the text is still delivered.

The payload category is `xulo`. Long-press the notification and the content extension shows the image, title, body, and a link. The link opens the app.

## In-app

Opening the app asks for a card. Call asks again with the name you type. The panel card has to be approved, and its trigger has to match. A named card uses the call name on screen.
