# prp-adminpanel

QBCore admin panel with:
- Live home dashboard and player activity wave graph
- Online players, job filters and admins online
- Search online/offline players
- Click player -> full profile with job, gang, money and inventory where available
- Built-in rich admin note editor with bold, underline, italic, bullet points and numbered lists
- Admin notes viewer with admin name and timestamp footer
- Ban history viewer
- Player logs for joins, drops and deaths
- Flag/warning system with configurable auto-punish kick
- Admin action audit log
- Developer tools for objects, closest object delete, vehicles and peds

## Install
1. Drop `prp-adminpanel` into your resources folder.
2. Ensure `oxmysql` and `qb-core` are started before this resource.
3. Add this to `server.cfg`:

```cfg
ensure prp-adminpanel
add_ace group.admin prp.adminpanel allow
add_ace group.god prp.adminpanel.dev allow
```

## Command
```txt
/adminpanel
```

## Notes
- The resource creates its own tables automatically: `prp_admin_notes`, `prp_player_logs`, `prp_admin_flags`, `prp_admin_audit`.
- Ban history reads from the standard QBCore `bans` table.
- Offline inventory reads from the standard QBCore `players.inventory` JSON column if your build stores it there.
- Auto-punish warning count is set in `config.lua` as `Config.AutoPunishWarnings`.
