Config = Config or {}

Config.DefaultCreditScore = 600
Config.MinCreditScore = 300
Config.MaxCreditScore = 850
Config.MaxActiveLoans = 2

Config.OverdueCheckMinutes = 30
Config.DefaultPaymentIntervalHours = 168
Config.MissedPaymentInterestBump = 0.015
Config.MaxInterestRate = 0.35
Config.MissedPaymentCreditPenalty = 25
Config.PaidLoanCreditGain = 18
Config.OnTimePaymentCreditGain = 3

Config.LoanProducts = {
    {
        id = 'starter',
        label = 'Starter Loan',
        amount = 5000,
        termPayments = 5,
        baseInterest = 0.08,
        minCreditScore = 450,
        paymentIntervalHours = 168,
    },
    {
        id = 'vehicle',
        label = 'Vehicle Finance',
        amount = 25000,
        termPayments = 10,
        baseInterest = 0.12,
        minCreditScore = 560,
        paymentIntervalHours = 168,
    },
    {
        id = 'business',
        label = 'Business Loan',
        amount = 75000,
        termPayments = 12,
        baseInterest = 0.16,
        minCreditScore = 650,
        paymentIntervalHours = 168,
    },
}
