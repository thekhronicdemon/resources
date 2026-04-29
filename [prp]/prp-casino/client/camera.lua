PRPCasinoCam = PRPCasinoCam or {}
PRPCasinoCam.Handle = nil

local function rotToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))

    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

function PRPCasinoCam.Start(tableEntity, tableData)
    if not tableEntity or not DoesEntityExist(tableEntity) then return end
    if not tableData or not tableData.camera then return end

    PRPCasinoCam.Stop(false)

    local camData = tableData.camera
    local camPos = GetOffsetFromEntityInWorldCoords(tableEntity, camData.coords.x, camData.coords.y, camData.coords.z)
    local lookAt = GetOffsetFromEntityInWorldCoords(tableEntity, camData.lookAt.x, camData.lookAt.y, camData.lookAt.z)

    PRPCasinoCam.Handle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(PRPCasinoCam.Handle, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(PRPCasinoCam.Handle, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(PRPCasinoCam.Handle, camData.fov or 50.0)
    SetCamActive(PRPCasinoCam.Handle, true)
    RenderScriptCams(true, true, 650, true, true)
end

function PRPCasinoCam.Stop(smooth)
    if PRPCasinoCam.Handle then
        RenderScriptCams(false, smooth ~= false, smooth == false and 0 or 650, true, true)
        DestroyCam(PRPCasinoCam.Handle, false)
        PRPCasinoCam.Handle = nil
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PRPCasinoCam.Stop(false)
end)
