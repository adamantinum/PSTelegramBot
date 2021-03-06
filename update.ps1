#!/usr/bin/pwsh

<#
    Copyright (c) 2020 Alessandro Piras
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

# Simple and silly script to use bot

$Token = Get-Content -Path token
$TelegramAPI = "https://api.telegram.org/bot$Token"

function Send-Reply {


	if (!$Global:UpdateID)
	{
		$Global:UpdateID = $Global:TGInput.result[0].update_id
	}
	
	$Global:UpdateID++

	./pwshbot $TGInput.result[0]
}

while (1)
{
	$Global:TGInput = Invoke-RestMethod -Uri "$TelegramAPI/getUpdates?offset=$Global:UpdateID"

	if ($Global:TGInput.result[0].update_id)
	{
		Send-Reply
	}
}
