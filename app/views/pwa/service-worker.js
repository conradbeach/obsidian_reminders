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
  const notification = event.notification
  notification.close()

  if (event.action === "complete") {
    event.waitUntil(complete(notification))
    return
  }

  const path = notification.data.path
  event.waitUntil(
    clients.matchAll({ type: "window" }).then((clientList) => {
      const client = clientList.find((client) => new URL(client.url).pathname === path && "focus" in client)
      return client ? client.focus() : clients.openWindow(path)
    })
  )
})

// Marks the reminder done. If the server can't be reached, the notification comes back so the Done button can be tried
// again, rather than the reminder silently staying undone.
const complete = (notification) =>
  fetch(notification.data.completion, { method: "POST" })
    .then((response) => { if (!response.ok) throw new Error(response.statusText) })
    .catch(() => self.registration.showNotification(notification.title, {
      body: "Couldn't mark this done. Try again.",
      data: notification.data,
      actions: notification.actions
    }))
