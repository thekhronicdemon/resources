INSTALL
1. Remove old chat theme resources that also override gtao.
2. Put this folder in resources.
3. In server.cfg:
   ensure chat
   ensure chat-theme-prp-alert
4. Restart server.

HOW TO USE
OOC:
TriggerEvent('chat:addMessage', {
    template = 'ooc',
    args = { 'Player Name (123)', 'lowkey just shot through a wall?' }
})

Invalid command prompt:
TriggerEvent('chat:addMessage', {
    template = 'invalidcmd',
    args = { '', '' }
})

This version is styled closer to the screenshot:
- dark compact bars
- yellow invalid command alert
- grouped follow-up messages
- fade out after 2 minutes
