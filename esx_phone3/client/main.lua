local Keys = {
  ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
  ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
  ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
  ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
  ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
  ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
  ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
  ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
  ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

local GUI                        = {}
local PhoneData                  = {phoneNumber = 0, contacts = {}, encryptingCard = false}
local RegisteredMessageCallbacks = {}
local ContactJustAdded           = false
local CurrentAction              = nil
local CurrentActionMsg           = ''
local CurrentActionData          = {}
local CurrentDispatchRequestId   = -1
local PhoneNumberSources         = {}
local CellphoneObject            = nil
local CallStartTime              = nil
local OnCall                     = false
local Flightmode                 = false
local settingsLoadedFromDatabase = false
local Sharelocation              = false
local GUI                        = {}
GUI.IsOpen                       = false
GUI.HasFocus                     = false

ESX = nil

Citizen.CreateThread(function()

  while ESX == nil do
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    Citizen.Wait(0)
  end

  ESX.UI.Menu.RegisterType('phone', OpenPhone, ClosePhone)

end)

-- GameExpress --

-- Bingo stuff --

RegisterNetEvent('bingo_core:phone:sendnui')
AddEventHandler('bingo_core:phone:sendnui', function(data)
    print('recieved data on luahandler')
    if data['vehicles'] ~= nil then
        for k, v in pairs(data['vehicles']) do
            local model = data['vehicles'][k]['model']
            local name = GetDisplayNameFromVehicleModel(math.floor(model))
            data['vehicles'][k]['name'] = name
            data['vehicles'][k]['class'] = GetVehicleClassFromName(name)
        end
    end

    if data['found'] == true then
        print('found in client, updating vehicle')
        TriggerEvent('currentvehicle:update', data['vehicle']['vehicle'])
    end
    SendNUIMessage(data)
end)

function OpenPhone()

  GUI.IsOpen      = true
  GUI.HasFocus    = false
  local playerPed = GetPlayerPed(-1)

  TriggerServerEvent('esx_phone:reload', PhoneData.phoneNumber)

  SendNUIMessage({
    showPhone = true
  })

  local coords     = GetEntityCoords(playerPed)
  local bone       = GetPedBoneIndex(playerPed, 28422)
  local phoneModel = GetHashKey('prop_npc_phone_02')

  Citizen.CreateThread(function()

	RequestAnimDict('cellphone@')
	
	while not HasAnimDictLoaded('cellphone@') do
	  Citizen.Wait(0)
	end

  TaskPlayAnim(playerPed, 'cellphone@', 'cellphone_text_read_base', 1.0, -1, -1, 50, 0, false, false, false)
    RequestModel(phoneModel)

    while not HasModelLoaded(phoneModel) do
      Citizen.Wait(0)
    end

    CellphoneObject = CreateObject(phoneModel, coords.x, coords.y, coords.z, 1, 1, 0)

    AttachEntityToEntity(CellphoneObject, playerPed, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0, 0, 2, 1)

  end)

   --TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_STAND_MOBILE", 0, true);

end

function ClosePhone()

  GUI.IsOpen      = false
  GUI.HasFocus    = false
  local playerPed = GetPlayerPed(-1)

  SendNUIMessage({
    showPhone = false
  })

  SetNuiFocus(false)

  ClearPedTasks(playerPed)

  DeleteObject(CellphoneObject)

end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)

  for i=1, #xPlayer.accounts, 1 do
    if xPlayer.accounts[i].name == 'bank' then

      SendNUIMessage({
        setBank = true,
        money   = xPlayer.accounts[i].money
      })

      break

    end
  end

end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts, encryptingCard, identifier)
    if settingsLoadedFromDatabase == false then
        settingsLoadedFromDatabase = true
        TriggerServerEvent('esx_phone:load_settings', identifier)
    end
  PhoneData.phoneNumber     = phoneNumber
  PhoneData.contacts        = {}
  PhoneData.encryptingCard  = encryptingCard
  PhoneData.identifier      = identifier

  for i=1, #contacts, 1 do
    table.insert(PhoneData.contacts, contacts[i])
  end

  SendNUIMessage({
    reloadPhone = true,
    phoneData   = PhoneData
  })

end)

RegisterNetEvent('esx_phone:load_settings')
AddEventHandler('esx_phone:load_settings', function(settings)

  SendNUIMessage({
    reloadSettings = true,
    settings = settings
  })

end)

RegisterNetEvent('esx_phone:addContact')
AddEventHandler('esx_phone:addContact', function(name, phoneNumber)

  table.insert(PhoneData.contacts, {
    name   = name,
    number = phoneNumber
  })

  SendNUIMessage({
    contactAdded = true,
    phoneData    = PhoneData
  })

end)

RegisterNetEvent('esx_phone:onMessage')
AddEventHandler('esx_phone:onMessage', function(phoneNumber, message, position, anon, job, dispatchRequestId)

	ESX.TriggerServerCallback('esx_phone:getPhoneStatus', function(hasPhone)
		if hasPhone and GetEntityHealth(GetPlayerPed(-1)) >= 100 then
			if job == 'player' then
				ESX.ShowNotification('Nytt meddelande : ' .. message)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
				Citizen.Wait(250)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
				Citizen.Wait(250)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
			else
				ESX.ShowNotification(job .. ': ' .. message)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
				Citizen.Wait(250)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
				Citizen.Wait(250)
				PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
			end

			print("dispatch: " .. tostring(dispatchRequestId))
			if dispatchRequestId then

				CurrentAction            = 'dispatch'
				CurrentActionMsg         = job .. ' - Tryck ~INPUT_CONTEXT~ för svara på samtalet'
				CurrentDispatchRequestId = dispatchRequestId

				CurrentActionData = {
					phoneNumber = anon and '-1' or phoneNumber,
					message     = message,
					position    = position,
					actions     = actions,
					anon        = anon,
					job         = job
				}

				ESX.SetTimeout(15000, function()
					CurrentAction = nil
				end)

			end
		end
	end)

	SendNUIMessage({
		newMessage  = true,
		phoneNumber = anon and '-1' or phoneNumber,
		message     = message,
		position    = position,
		anon        = anon,
		job         = job
	})
end)

RegisterNetEvent('esx_phone:stopDispatch')
AddEventHandler('esx_phone:stopDispatch', function(dispatchRequestId, playerName, policeDispatch)
	if CurrentDispatchRequestId == dispatchRequestId and CurrentAction == 'dispatch' and not policeDispatch then
		CurrentAction = nil
		ESX.ShowNotification(playerName .. _U('taken_call'))
	elseif policeDispatch then
		CurrentDispatchRequestId = 99999
	end
end)

RegisterNetEvent('esx_phone:incomingCall')
AddEventHandler('esx_phone:incomingCall', function(target, channel, number)

  if not OnCall and not Flightmode then

    ESX.UI.Menu.Open('phone', GetCurrentResourceName(), 'main')

    SendNUIMessage({
      incomingCall = true,
      target       = target,
      channel      = channel,
      number       = number,
    })

  end

end)

RegisterNetEvent('esx_phone:onAcceptCall')
AddEventHandler('esx_phone:onAcceptCall', function(channel, target)

  OnCall = true

  SendNUIMessage({
    acceptedCall = true,
    channel      = channel,
    target       = target,
  })

  NetworkSetVoiceChannel(channel)
  NetworkSetTalkerProximity(0.0)

end)


RegisterNetEvent('esx_phone:endCall')
AddEventHandler('esx_phone:endCall', function(msg)

  OnCall = false

  if msg ~= nil then
    ESX.ShowNotification(msg)
  end

  if CallStartTime ~= nil then
    TriggerServerEvent('esx_phone:billCall', Citizen.InvokeNative(0x9A73240B49945C76) - CallStartTime)
    CallStartTime = nil
  end

  SendNUIMessage({
    endCall = true
  })

  NetworkClearVoiceChannel()
  NetworkSetTalkerProximity(2.5)

  RequestAnimDict('anim@cellphone@in_car@ps')

  while not HasAnimDictLoaded('anim@cellphone@in_car@ps') do
    Citizen.Wait(0)
  end

  TaskPlayAnim(GetPlayerPed(-1), 'anim@cellphone@in_car@ps', 'cellphone_text_read_base', 1.0, -1, -1, 50, 0, false, false, false)

end)

RegisterNetEvent('esx_phone:openPhone')
AddEventHandler('esx_phone:openPhone', function()
  ESX.UI.Menu.CloseAll()
  ESX.UI.Menu.Open('phone', GetCurrentResourceName(), 'main')
end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)

  if account.name == 'bank' then
    SendNUIMessage({
      setBank = true,
      money   = account.money
    })
  end

end)

AddEventHandler('esx_phone:showIcon', function(icon, show)

  if show then
    SendNUIMessage({
      showIcon = true,
      icon     = icon
    })
  else
    SendNUIMessage({
      showIcon = false,
      icon     = icon
    })
  end

end)

RegisterNUICallback('activate_gps', function(data)
  SetNewWaypoint(data.x, data.y)
  ESX.ShowNotification('Ställning in i GPS')
end)

-- Save settings
RegisterNUICallback('save_settings', function(data)
    TriggerServerEvent('esx_phone:save_settings', data)
end)

-- Darkweb
RegisterNUICallback('darkweb_get_messages', function()
    RegisterNetEvent('bingo_core:darkweb_get_messages')
    TriggerServerEvent('bingo_core:darkweb_get_messages')
end)
RegisterNUICallback('darkweb_post_message', function(message, cb)
    RegisterNetEvent('bingo_core:darkweb_post_message')
    TriggerServerEvent('bingo_core:darkweb_post_message', message)
    cb('ok')
end)

-- Din bil app
RegisterNUICallback('request_mechanic', function(veh, cb)
    local coords = GetEntityCoords(veh)
    local health = GetVehicleBodyHealth(veh)
    local engineHealth = GetVehicleEngineHealth(veh)
    local message = 'Mekaniker behövs vid bifogad position. Skick: ' .. round(health/10, 2)  .. '%. Motor: ' .. round(engineHealth/10, 2) .. '%. Skickat från Din bil.'

    TriggerServerEvent('esx_phone:send', 'mecano', message, false, {
          x = coords.x,
          y = coords.y,
          z = coords.z
      });
  ESX.ShowNotification('Mekaniker tillkallad')
  cb('ok')
end)
RegisterNUICallback('request_mechanic_towing', function(veh, cb)
    local coords = GetEntityCoords(veh)
    local health = GetVehicleBodyHealth(veh)
    local engineHealth = GetVehicleEngineHealth(veh)
    local message = 'Bärgare behövs vid bifogad position. Skick: ' .. round(health/10, 2)  .. '%. Motor: ' .. round(engineHealth/10, 2) .. '%. Skickat från Din bil.'

    TriggerServerEvent('esx_phone:send', 'mecano', message, false, {
          x = coords.x,
          y = coords.y,
          z = coords.z
      })
  ESX.ShowNotification('Bärgare tillkallad')
  cb('ok')
end)

RegisterNUICallback('set_flightmode', function(val, cb)
  Flightmode = val
  cb('ok')
end)

RegisterNUICallback('set_sharelocation', function(val, cb)
  Sharelocation = val
  cb('ok')
end)

RegisterNUICallback('update_current_vehicle', function(plate, cb)
    TriggerEvent('currentvehicle:startLooking', plate)
    cb('ok')
end)
RegisterNUICallback('search_nearby', function(vehicleList, cb)
    TriggerEvent('currentvehicle:startLooking', vehicleList)
    cb('ok')
end)
RegisterNUICallback('update_vehicle_list', function()
    RegisterNetEvent('bingo_core:updateVehicles')
    TriggerServerEvent('bingo_core:updateVehicles')
end)

RegisterNUICallback('test_honk', function(veh, cb)
    TriggerEvent('currentvehicle:testHonk', veh)
    cb('ok')
end)

RegisterNUICallback('set_engine_off', function(veh, cb)
    TriggerEvent('currentvehicle:setEngine', veh, 0)
    cb('ok')
end)

RegisterNUICallback('set_engine_on', function(veh, cb)
    TriggerEvent('currentvehicle:setEngine', veh, 1)
    cb('ok')
end)

RegisterNUICallback('update_current_vehicle_known', function(veh, cb)
    TriggerEvent('currentvehicle:update', veh)
    cb('ok')
end)

RegisterNUICallback('start_call', function(data, cb)
  CallStartTime = Citizen.InvokeNative(0x9A73240B49945C76)
  TriggerServerEvent('esx_phone:startCall', data.number)

  RequestAnimDict('cellphone@')

  while not HasAnimDictLoaded('cellphone@') do
    Citizen.Wait(0)
  end

  TaskPlayAnim(GetPlayerPed(-1), 'cellphone@', 'cellphone_call_listen_base', 1.0, -1, -1, 50, 0, false, false, false)

  cb('OK')
end)

RegisterNUICallback('accept_call', function(data, cb)

    RequestAnimDict('cellphone@')

    while not HasAnimDictLoaded('cellphone@') do
      Citizen.Wait(0)
    end

    TaskPlayAnim(GetPlayerPed(-1), 'cellphone@', 'cellphone_call_listen_base', 1.0, -1, -1, 50, 0, false, false, false)
  OnCall = true

  TriggerServerEvent('esx_phone:acceptCall', data.target, data.channel)
  NetworkSetVoiceChannel(data.channel)
  NetworkSetTalkerProximity(0.0)
  cb('OK')
end)

RegisterNUICallback('end_call', function(data, cb)
  TriggerServerEvent('esx_phone:endCall', data.channel, data.target)
  cb('OK')
end)

RegisterNUICallback('send', function(data)

  local phoneNumber = data.number
  local playerPed   = GetPlayerPed(-1)
  local coords      = GetEntityCoords(playerPed)

  if tonumber(phoneNumber) ~= nil then
	phoneNumber = tonumber(phoneNumber)
  end

  TriggerServerEvent('esx_phone:send', phoneNumber, data.message, data.anon, {
	x = coords.x,
	y = coords.y,
	z = coords.z
  })

  ESX.ShowNotification('Meddelande skickat')

end)

RegisterNUICallback('remove_contact', function(data, cb)
	print("tar bort" .. data.number)
	local phoneNumber = tonumber(data.number)

	if phoneNumber then
		TriggerServerEvent('esx_phone:removePlayerContact', phoneNumber)

		for i=#PhoneData.contacts, 1, -1 do
			if PhoneData.contacts[i].number == phoneNumber then
				table.remove(PhoneData.contacts, i)

				print(json.encode(PhoneData))

				SendNUIMessage({
					reloadPhone = true,
					phoneData   = PhoneData
				})
			end
		end
	end

	cb('OK')
end)

RegisterNUICallback('add_contact', function(data, cb)

  local phoneNumber = tonumber(data.phoneNumber)
  local contactName = tostring(data.contactName)

  if phoneNumber then
    TriggerServerEvent('esx_phone:addPlayerContact', phoneNumber, contactName)
  end

  cb('OK')

end)

RegisterNUICallback('escape', function()
  ESX.UI.Menu.Close('phone', GetCurrentResourceName(), 'main')
end)

RegisterNUICallback('request_focus', function()
  GUI.HasFocus = true
  SetNuiFocus(true, true)
end)

RegisterNUICallback('request_input_focus', function()
  GUI.HasFocus = true
  SetNuiFocus(true, false)
end)

RegisterNUICallback('release_focus', function()
  GUI.HasFocus = false
  SetNuiFocus(false)
end)

RegisterNUICallback('request_vehicle_data', function()
    TriggerServerEvent('bingo_core:updateVehicles');
end)

RegisterNUICallback('show_vehicle_blip', function(veh, cb)
    TriggerEvent('currentVehicle:showOnMap', veh);
    cb('ok');
end)
RegisterNUICallback('hide_vehicle_blip', function()
    TriggerEvent('currentVehicle:hideOnMap');
end)

RegisterNUICallback('request_current_vehicle_data', function(plate, cb)
    TriggerServerEvent('bingo_core:updateCurrentVehicle', plate);
    cb('ok');
end)

RegisterNUICallback('lock_car', function(veh, cb)
    TriggerEvent('currentvehicle:setLock', veh, true);
    cb('ok');
end)
RegisterNUICallback('unlock_car', function(veh, cb)
    TriggerEvent('currentvehicle:setLock', veh, false);
    cb('ok');
end)

RegisterNUICallback('bingo_checknumber', function(number, cb)
    TriggerServerEvent('bingo_core:phone:checkNumber', number);
    cb('ok');
end)
RegisterNUICallback('bingo_updatenumber', function(number, cb)
    TriggerServerEvent('bingo_core:phone:updateNumber', number);
    cb('ok');
end)
RegisterNUICallback('bingo_resetphone', function()
    ClosePhone();
    ESX.ShowNotification('Återställer telefon');
    TriggerServerEvent('esx_phone:reset_phone', ESX.GetPlayerData());
end)

RegisterNUICallback('get_players', function(data, cb)

  local players  = ESX.Game.GetPlayers()
  local _players = {}

  for i=1, #players, 1 do
    --if players[i] ~= PlayerId() then
      table.insert(_players, {
        source = GetPlayerServerId(players[i]),
        name   = GetPlayerName(players[i])
      })
    --end
  end

  SendNUIMessage({
    onPlayers = true,
    players   = _players,
    reason    = data.reason
  })

  cb('OK')

end)

RegisterNUICallback('bank_transfer', function(data, cb)

  local amount = tonumber(data.amount)

  if amount ~= nil then
    TriggerServerEvent('esx_phone:bankTransfer', data.player, amount)
  else
    ESX.ShowNotification('Ogiltigt belopp')
  end

end)

-- Key controls
Citizen.CreateThread(function()
  while true do

	Wait(0)

	if GUI.IsOpen then

	  if IsControlJustReleased(0, Keys['TOP']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'TOP'
		})
	  end

	  if IsControlJustReleased(0, Keys['DOWN']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'DOWN'
		})
	  end

	  if IsControlJustReleased(0, Keys['LEFT']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'LEFT'
		})
	  end

	  if IsControlJustReleased(0, Keys['RIGHT']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'RIGHT'
		})
	  end

	  if IsControlJustReleased(0, Keys['ENTER']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'ENTER'
		})
	  end

	  if IsControlJustReleased(0, Keys['BACKSPACE']) then
		SendNUIMessage({
		  controlPressed = true,
		  control        = 'BACKSPACE'
		})
	  end

	end

	if GUI.HasFocus then -- codes here: https://pastebin.com/guYd0ht4
	  DisableControlAction(0, 1,    true) -- LookLeftRight
	  DisableControlAction(0, 2,    true) -- LookUpDown
	  DisableControlAction(0, 25,   true) -- Input Aim
	  DisableControlAction(0, 106,  true) -- Vehicle Mouse Control Override

	  DisableControlAction(0, 24,   true) -- Input Attack
	  DisableControlAction(0, 140,  true) -- Melee Attack Alternate
	  DisableControlAction(0, 141,  true) -- Melee Attack Alternate
	  DisableControlAction(0, 142,  true) -- Melee Attack Alternate
	  DisableControlAction(0, 257,  true) -- Input Attack 2
	  DisableControlAction(0, 263,  true) -- Input Melee Attack
	  DisableControlAction(0, 264,  true) -- Input Melee Attack 2

	  DisableControlAction(0, 12,   true) -- Weapon Wheel Up Down
	  DisableControlAction(0, 14,   true) -- Weapon Wheel Next
	  DisableControlAction(0, 15,   true) -- Weapon Wheel Prev
	  DisableControlAction(0, 16,   true) -- Select Next Weapon
	  DisableControlAction(0, 17,   true) -- Select Prev Weapon
	else

	  if IsDisabledControlJustReleased(0, Keys['F1']) and GetEntityHealth(GetPlayerPed(-1)) >= 100 then
		TriggerServerEvent('esx_phone:tryOpenPhone')
	  end

	  if IsControlJustReleased(0, Keys['U']) and GUI.IsOpen then
		
		SendNUIMessage({
		  activateGPS = true
		})
	 
	  end

	end
  end
end)

-- Key controls
Citizen.CreateThread(function()

  SetNuiFocus(false)

  while true do

	Citizen.Wait(0)

	if CurrentAction ~= nil then

	  SetTextComponentFormat('STRING')
	  AddTextComponentString(CurrentActionMsg)
	  DisplayHelpTextFromStringLabel(0, 0, 1, -1)

	  if IsControlJustReleased(0, Keys['E']) then

		if CurrentAction == 'dispatch' then
			ESX.TriggerServerCallback('esx_phone:getIdentity', function(identity)
				local playerData = ESX.GetPlayerData()
				if playerData.job.name ~= 'police' and playerData.job.name ~= 'ambulance' then
					TriggerServerEvent('esx_phone:send', playerData.job.name, identity.firstname .. ' tar det samtalet.', false, {}, true)
					TriggerServerEvent('esx_phone:send', CurrentActionData.phoneNumber, identity.firstname .. ' kommer så fort som möjligt, var god vänta på platsen.', false)
					TriggerServerEvent('esx_phone:stopDispatch', CurrentDispatchRequestId)
				elseif playerData.job.name == 'ambulance' then
					TriggerServerEvent('esx_phone:send', playerData.job.name, 'En enhet har åkt iväg på senast inkomna samtal. Invänta uppgifter!', false, {}, true)
					TriggerServerEvent('esx_phone:send', CurrentActionData.phoneNumber, 'SOS Operatör: Ambulans är på väg mot din angivna larmposition. Vid skada på andra part, kontrollera så personen har puls och fria luftvägar. Om inte, påbörja hjärt- och lungräddning!', false)
					TriggerServerEvent('esx_phone:stopDispatch', CurrentDispatchRequestId)
				elseif playerData.job.name == 'police' and CurrentDispatchRequestId ~= 99999 then
					TriggerServerEvent('esx_phone:send', playerData.job.name, 'En patrull har åkt iväg på senast inkomna samtal. Invänta uppgifter!', false, {}, true)
					TriggerServerEvent('esx_phone:send', CurrentActionData.phoneNumber, 'SOS Operatör: Polis är på väg mot din angivna larmpostion. Vänligen invänta ingripande patrull för att ange uppgifter. Vid personskador, larma ambulans och försäkra dig om att personen har puls och fria luftvägar. Om inte, påbörja hjärt- och lungräddning!', false)
					TriggerServerEvent('esx_phone:stopDispatch', CurrentDispatchRequestId, true)
				end
				SetNewWaypoint(CurrentActionData.position.x,  CurrentActionData.position.y)
			end)
		end

		CurrentAction = nil

	  end

	end

  end
end)


-- simple round with decimals
function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end
