self.addEventListener("push", (event) => {
  const { title, options } = event.data.json()
  event.waitUntil(self.registration.showNotification(title, options))
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
