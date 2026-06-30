local QBCore = exports['qb-core']:GetCoreObject()
local TablesReady = false
local TablesCreating = false

local function Clamp(value, min, max)
    value = tonumber(value) or min
    if value < min then return min end
    if value > max then return max end
    return value
end

local function Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function GetPlayerName(Player)
    local charinfo = Player and Player.PlayerData and Player.PlayerData.charinfo or {}
    local first = charinfo.firstname or ''
    local last = charinfo.lastname or ''
    local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or 'Unknown'
end

local function GetProduct(productId)
    for _, product in ipairs(Config.LoanProducts or {}) do
        if product.id == productId then
            return product
        end
    end
    return nil
end

local function GetCreditRating(score)
    score = tonumber(score) or Config.DefaultCreditScore
    if score >= 760 then return 'Excellent' end
    if score >= 700 then return 'Good' end
    if score >= 620 then return 'Fair' end
    if score >= 540 then return 'Risky' end
    return 'Poor'
end

local function CalculateInterestRate(product, creditScore)
    local rate = tonumber(product.baseInterest) or 0.1
    local score = tonumber(creditScore) or Config.DefaultCreditScore

    if score < 650 then
        rate = rate + (math.ceil((650 - score) / 25) * 0.005)
    elseif score >= 760 then
        rate = math.max(rate - 0.015, 0.01)
    end

    return math.min(rate, Config.MaxInterestRate or 0.35)
end

local function CalculatePayment(amount, interestRate, termPayments)
    amount = tonumber(amount) or 0
    interestRate = tonumber(interestRate) or 0
    termPayments = math.max(tonumber(termPayments) or 1, 1)
    return Round((amount + (amount * interestRate)) / termPayments)
end

local function EnsureTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `prp_finance_profiles` (
            `citizenid` varchar(50) NOT NULL,
            `credit_score` int NOT NULL DEFAULT 600,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `prp_finance_loans` (
            `id` int NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `label` varchar(80) NOT NULL,
            `principal` int NOT NULL DEFAULT 0,
            `balance` int NOT NULL DEFAULT 0,
            `interest_rate` decimal(7,4) NOT NULL DEFAULT 0.0000,
            `payment_amount` int NOT NULL DEFAULT 0,
            `term_payments` int NOT NULL DEFAULT 1,
            `payments_made` int NOT NULL DEFAULT 0,
            `missed_payments` int NOT NULL DEFAULT 0,
            `next_payment_at` int NOT NULL DEFAULT 0,
            `payment_interval` int NOT NULL DEFAULT 604800,
            `status` varchar(20) NOT NULL DEFAULT 'active',
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid_status` (`citizenid`, `status`),
            KEY `next_payment_at` (`next_payment_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    TablesReady = true
end

local function EnsureTablesReady()
    if TablesReady then return true end

    if TablesCreating then
        while TablesCreating and not TablesReady do
            Wait(50)
        end
        return TablesReady
    end

    TablesCreating = true
    local ok, err = pcall(EnsureTables)
    TablesCreating = false

    if not ok then
        print(('[prp-finance] Failed to ensure tables: %s'):format(err))
        return false
    end

    return TablesReady
end

local function EnsureProfile(citizenid)
    if not citizenid or citizenid == '' then return nil end
    if not EnsureTablesReady() then return nil end

    MySQL.insert.await('INSERT IGNORE INTO prp_finance_profiles (citizenid, credit_score) VALUES (?, ?)', {
        citizenid,
        Config.DefaultCreditScore or 600
    })

    local profile = MySQL.single.await('SELECT citizenid, credit_score AS creditScore FROM prp_finance_profiles WHERE citizenid = ?', {
        citizenid
    })

    if profile then
        profile.rating = GetCreditRating(profile.creditScore)
    end

    return profile
end

local function SetCreditScore(citizenid, score)
    score = Clamp(score, Config.MinCreditScore or 300, Config.MaxCreditScore or 850)
    MySQL.update.await('UPDATE prp_finance_profiles SET credit_score = ? WHERE citizenid = ?', {
        score,
        citizenid
    })
    return score
end

local function AdjustCreditScore(citizenid, amount)
    local profile = EnsureProfile(citizenid)
    if not profile then return nil end
    return SetCreditScore(citizenid, (tonumber(profile.creditScore) or Config.DefaultCreditScore) + (tonumber(amount) or 0))
end

local function GetLoans(citizenid)
    if not EnsureTablesReady() then return {} end

    local rows = MySQL.query.await([[
        SELECT id, label, principal, balance, interest_rate AS interestRate, payment_amount AS paymentAmount,
               term_payments AS termPayments, payments_made AS paymentsMade, missed_payments AS missedPayments,
               next_payment_at AS nextPaymentAt, payment_interval AS paymentInterval, status
        FROM prp_finance_loans
        WHERE citizenid = ? AND status = 'active'
        ORDER BY created_at DESC
    ]], { citizenid })

    return rows or {}
end

local function CountActiveLoans(citizenid)
    if not EnsureTablesReady() then return 0 end

    local row = MySQL.single.await('SELECT COUNT(*) AS total FROM prp_finance_loans WHERE citizenid = ? AND status = ?', {
        citizenid,
        'active'
    })
    return tonumber(row and row.total) or 0
end

local function BuildProducts(creditScore)
    local products = {}

    for _, product in ipairs(Config.LoanProducts or {}) do
        local interestRate = CalculateInterestRate(product, creditScore)
        local paymentAmount = CalculatePayment(product.amount, interestRate, product.termPayments)
        local available = creditScore >= (tonumber(product.minCreditScore) or 0)

        products[#products + 1] = {
            id = product.id,
            label = product.label,
            amount = tonumber(product.amount) or 0,
            termPayments = tonumber(product.termPayments) or 1,
            interestRate = interestRate,
            paymentAmount = paymentAmount,
            available = available,
            reason = available and nil or ('Requires credit score %s.'):format(product.minCreditScore or 0),
        }
    end

    return products
end

local function BuildProfileResponse(Player, message, success)
    local citizenid = Player.PlayerData.citizenid
    local profile = EnsureProfile(citizenid)

    return {
        success = success ~= false,
        message = message,
        profile = profile,
        products = BuildProducts(tonumber(profile and profile.creditScore) or Config.DefaultCreditScore),
        loans = GetLoans(citizenid),
    }
end

local function GetOnlinePlayerByCitizenId(citizenid)
    for _, src in ipairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.citizenid == citizenid then
            return Player
        end
    end
    return nil
end

local function ProcessOverdueLoans()
    if not TablesReady then return end

    local now = os.time()
    local rows = MySQL.query.await([[
        SELECT id, citizenid, label, balance, interest_rate AS interestRate, payment_interval AS paymentInterval,
               missed_payments AS missedPayments
        FROM prp_finance_loans
        WHERE status = 'active' AND next_payment_at > 0 AND next_payment_at < ?
    ]], { now })

    for _, loan in ipairs(rows or {}) do
        local bump = tonumber(Config.MissedPaymentInterestBump) or 0.015
        local balance = tonumber(loan.balance) or 0
        local fee = math.max(Round(balance * bump), 1)
        local newRate = math.min((tonumber(loan.interestRate) or 0) + bump, Config.MaxInterestRate or 0.35)
        local interval = tonumber(loan.paymentInterval) or ((Config.DefaultPaymentIntervalHours or 168) * 3600)
        local missed = (tonumber(loan.missedPayments) or 0) + 1

        MySQL.update.await([[
            UPDATE prp_finance_loans
            SET balance = ?, interest_rate = ?, missed_payments = ?, next_payment_at = ?
            WHERE id = ?
        ]], {
            balance + fee,
            newRate,
            missed,
            now + interval,
            loan.id
        })

        local newScore = AdjustCreditScore(loan.citizenid, -(Config.MissedPaymentCreditPenalty or 25))
        local Player = GetOnlinePlayerByCitizenId(loan.citizenid)
        if Player then
            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, ('Missed finance payment: %s. Credit score now %s.'):format(loan.label, newScore or 'lower'), 'error')
        end
    end
end

QBCore.Functions.CreateCallback('prp-finance:server:GetProfile', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    cb(BuildProfileResponse(Player))
end)

QBCore.Functions.CreateCallback('prp-finance:server:ApplyLoan', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local product = GetProduct(data.productId)
    if not product then
        cb(BuildProfileResponse(Player, 'Unknown loan product.', false))
        return
    end

    local profile = EnsureProfile(Player.PlayerData.citizenid)
    local creditScore = tonumber(profile and profile.creditScore) or Config.DefaultCreditScore
    if creditScore < (tonumber(product.minCreditScore) or 0) then
        cb(BuildProfileResponse(Player, 'Credit score is too low for this loan.', false))
        return
    end

    if CountActiveLoans(Player.PlayerData.citizenid) >= (Config.MaxActiveLoans or 2) then
        cb(BuildProfileResponse(Player, 'You already have too many active loans.', false))
        return
    end

    local amount = tonumber(product.amount) or 0
    if amount <= 0 then
        cb(BuildProfileResponse(Player, 'Loan amount is invalid.', false))
        return
    end

    local interestRate = CalculateInterestRate(product, creditScore)
    local termPayments = math.max(tonumber(product.termPayments) or 1, 1)
    local paymentAmount = CalculatePayment(amount, interestRate, termPayments)
    local balance = paymentAmount * termPayments
    local interval = (tonumber(product.paymentIntervalHours) or Config.DefaultPaymentIntervalHours or 168) * 3600

    Player.Functions.AddMoney('bank', amount, 'finance loan deposit')
    MySQL.insert.await([[
        INSERT INTO prp_finance_loans
        (citizenid, label, principal, balance, interest_rate, payment_amount, term_payments, next_payment_at, payment_interval)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        Player.PlayerData.citizenid,
        product.label,
        amount,
        balance,
        interestRate,
        paymentAmount,
        termPayments,
        os.time() + interval,
        interval
    })

    cb(BuildProfileResponse(Player, ('Approved %s for %s.'):format(product.label, GetPlayerName(Player))))
end)

QBCore.Functions.CreateCallback('prp-finance:server:MakePayment', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({ success = false, message = 'Player not found.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local loanId = tonumber(data.loanId)
    if not loanId then
        cb(BuildProfileResponse(Player, 'Loan not found.', false))
        return
    end

    local loan = MySQL.single.await('SELECT * FROM prp_finance_loans WHERE id = ? AND citizenid = ? AND status = ?', {
        loanId,
        Player.PlayerData.citizenid,
        'active'
    })

    if not loan then
        cb(BuildProfileResponse(Player, 'Loan not found.', false))
        return
    end

    local balance = tonumber(loan.balance) or 0
    local requested = tonumber(data.amount) or tonumber(loan.payment_amount) or balance
    local amount = math.min(math.max(Round(requested), 1), balance)

    if not Player.Functions.RemoveMoney('bank', amount, 'finance loan payment') then
        cb(BuildProfileResponse(Player, 'Not enough money in bank.', false))
        return
    end

    local remaining = balance - amount
    local paymentsMade = (tonumber(loan.payments_made) or 0) + 1
    if remaining <= 0 then
        MySQL.update.await('UPDATE prp_finance_loans SET balance = 0, payments_made = ?, status = ? WHERE id = ?', {
            paymentsMade,
            'paid',
            loanId
        })
        AdjustCreditScore(Player.PlayerData.citizenid, Config.PaidLoanCreditGain or 18)
        cb(BuildProfileResponse(Player, 'Loan paid off. Credit score improved.'))
        return
    end

    local interval = tonumber(loan.payment_interval) or ((Config.DefaultPaymentIntervalHours or 168) * 3600)
    MySQL.update.await('UPDATE prp_finance_loans SET balance = ?, payments_made = ?, next_payment_at = ? WHERE id = ?', {
        remaining,
        paymentsMade,
        os.time() + interval,
        loanId
    })
    AdjustCreditScore(Player.PlayerData.citizenid, Config.OnTimePaymentCreditGain or 3)

    cb(BuildProfileResponse(Player, ('Paid $%s toward %s.'):format(amount, loan.label)))
end)

exports('GetFinanceProfile', function(citizenid)
    local profile = EnsureProfile(citizenid)
    if not profile then return nil end
    return {
        profile = profile,
        products = BuildProducts(tonumber(profile.creditScore) or Config.DefaultCreditScore),
        loans = GetLoans(citizenid),
    }
end)

CreateThread(function()
    Wait(1000)
    EnsureTablesReady()
    ProcessOverdueLoans()

    while true do
        Wait((Config.OverdueCheckMinutes or 30) * 60000)
        ProcessOverdueLoans()
    end
end)
