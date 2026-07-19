PRPDrugs = PRPDrugs or {}

function PRPDrugs.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function PRPDrugs.Round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(value * power + 0.5) / power
end

function PRPDrugs.GetStrain(quality)
    quality = PRPDrugs.Clamp(quality, 1, 100)
    if quality >= 96 then return 'AK47' end
    if quality >= 91 then return 'Purple Haze' end
    if quality >= 86 then return 'Amnesia' end
    if quality >= 81 then return 'Skunk' end
    if quality >= 76 then return 'OG-Kush' end
    return 'Whitewidow'
end

function PRPDrugs.GetQualityLabel(quality)
    quality = PRPDrugs.Clamp(quality, 1, 100)
    if quality >= 96 then return 'Perfect' end
    if quality >= 91 then return 'Exceptional' end
    if quality >= 86 then return 'Premium' end
    if quality >= 81 then return 'High Grade' end
    if quality >= 76 then return 'Good' end
    if quality >= 60 then return 'Common' end
    return 'Low Grade'
end

function PRPDrugs.BuildInfo(quality, extra)
    quality = PRPDrugs.Round(PRPDrugs.Clamp(quality, 1, 100), 1)
    local info = {
        quality = quality,
        strain = PRPDrugs.GetStrain(quality),
        qualityLabel = PRPDrugs.GetQualityLabel(quality),
        description = ('%s | %.1f%% quality'):format(PRPDrugs.GetStrain(quality), quality),
    }
    if extra then
        for key, value in pairs(extra) do info[key] = value end
    end
    return info
end

function PRPDrugs.DecodeInfo(item)
    if not item then return {} end
    return item.info or item.metadata or {}
end
