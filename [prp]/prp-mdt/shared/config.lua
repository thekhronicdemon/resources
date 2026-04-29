Config = {}

Config.Command = 'mdt'
Config.AllowedJobs = {
    police = true,
    sheriff = true,
    doj = true,
    lawyer = true,
    ambulance = false
}

Config.BossGrades = {
    police = 4,
    sheriff = 4,
    doj = 3
}

Config.DefaultLogo = 'images/logo.png'

Config.Licenses = {
    driver = 'Car',
    weapon = 'Gun',
    fishing = 'Fishing'
}

Config.Charges = {
    { id = 'accessory-controlled-substance', title = 'Accessory to Controlled Substance Distribution', category = 'Conspiracy', fine = 3500, months = 19, type = 'Accessory', description = 'Assisting a controlled substance distribution offense.' },
    { id = 'conspiracy-controlled-substance', title = 'Conspiracy to Manufacture Controlled Substance', category = 'Conspiracy', fine = 10000, months = 15, type = 'Conspiracy', description = 'Coordinating a manufacturing offense before completion.' },
    { id = 'possession-marijuana', title = 'Possession of Controlled Substance (Marijuana)', category = 'Controlled Substance', fine = 1000, months = 0, type = 'Principal', description = 'Simple possession of marijuana.' },
    { id = 'possession-distribute-marijuana', title = 'Possession with Intent to Distribute (Marijuana)', category = 'Controlled Substance', fine = 5000, months = 26, type = 'Principal', description = 'Possession with intent to distribute marijuana.' },
    { id = 'manufacture-controlled-substance-marijuana', title = 'Manufacture of Controlled Substance (Marijuana)', category = 'Controlled Substance', fine = 25000, months = 30, type = 'Principal', description = 'Manufacturing controlled substances.' },
    { id = 'possession-meth', title = 'Possession of Controlled Substance (Meth)', category = 'Controlled Substance', fine = 2500, months = 15, type = 'Principal', description = 'Simple possession of methamphetamine.' },
    { id = 'reckless-driving', title = 'Reckless Driving', category = 'Traffic', fine = 1500, months = 0, type = 'Misdemeanor', description = 'Driving with reckless disregard.' },
    { id = 'evading-police', title = 'Evading Police', category = 'Traffic', fine = 5000, months = 20, type = 'Felony', description = 'Failing to stop for lawful police direction.' },
    { id = 'assault', title = 'Assault', category = 'Violent Crime', fine = 3500, months = 15, type = 'Misdemeanor', description = 'Attempted or threatened bodily harm.' },
    { id = 'aggravated-assault', title = 'Aggravated Assault', category = 'Violent Crime', fine = 8500, months = 35, type = 'Felony', description = 'Serious assault with aggravating factors.' }
}

Config.EvidenceSlots = 40
Config.EvidenceWeight = 100000
