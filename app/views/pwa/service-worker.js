self.addEventListener("push", (event) => {
  const { title, options, receipt } = event.data.json()

  // Tells the server the notification arrived, and then that it was shown, so one that never appeared shows where it
  // was lost.
  const report = (stage) => fetch(receipt, { method: "POST", body: new URLSearchParams({ stage }) }).catch(() => {})

  event.waitUntil(Promise.all([
    report("received"),
    self.registration.showNotification(title, options).then(() => report("shown"))
  ]))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const path = event.notification.data.path

  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      const client = clientList.find((client) => new URL(client.url).pathname === path && "focus" in client)
      return client ? client.focus() : clients.openWindow(path)
    })
  )
})
