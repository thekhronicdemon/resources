Config = {}

Config.Command = 'adminpanel'

-- Supported: qbcore, ace, both
Config.PermissionMode = 'both'
Config.QBPermissions = { 'god', 'admin' }
Config.AcePermission = 'prp.adminpanel'

Config.MaxSpawnedVehiclesPerAdmin = 3
Config.MaxSpawnedObjectsPerAdmin = 25
Config.MaxSpawnedPedsPerAdmin = 10

Config.DefaultBanHours = 24
Config.AutoPunishWarnings = 3 -- warning flags before automatic kick; set false/nil to disable
Config.MaxNoteLength = 5000

Config.JobButtons = {
    { label = 'Police', job = 'police' },
    { label = 'EMS', job = 'ambulance' },
    { label = 'Mechanic', job = 'mechanic' }
}

Config.AdminGroups = {
    god = true,
    admin = true,
    mod = true
}

Config.EnableDevTools = true
Config.DevToolsRequireGod = true

Config.ActivityBuckets = 24 -- hourly wave graph
Config.ActivitySampleMinutes = 1 -- lower = more live accurate peak tracking
