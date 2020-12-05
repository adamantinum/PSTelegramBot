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

param (
   $TGInput
)

function prompt {
	$(if (Test-Path -Path variable:/PSDebugContext) { "[$(Get-Date -UFormat "%F %H:%M:%s")]" })
}

&{
   $Token = Get-Content -Path token
   $TelegramAPI = "https://api.telegram.org/bot$Token"

   $StartTime = Get-Date -UFormat %s
   
   Set-PSDebug -Trace 2

   function Invoke-Sth {
	   param ( 
	   $global:Arg1,
	   $global:Arg2
	   )

	   Switch($global:Arg1)
	   {
		   1 {
			   $global:TextID = "processing..."
			   $global:ProcessingID = (Deploy-TGMethod send_message).result[0].message_id
		   }

		   2 {
			   $global:ToEditID = $global:ProcessingID
			   $global:EditText = "sending..."
			   $global:EditedID = (Deploy-TGMethod edit_message).result[0].message_id
		   }

		   3 {
			   $global:ToDeleteID = $global:EditionID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }

		   value {
			   $global:ToEditID = $global:ProcessingID
			   $global:EditText = $global:Arg2
			   $global:ProcessingID = (Deploy-TGMethod edit_message).result[0].message_id
		   }

		   error {
			   $global:ToDeleteID = $global:ProcessingID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Find-Subreddit {
	   param (
	   $TGInput,
	   $global:Key
	   )

	   $global:Subreddit = $TGInput
	   $global:Sort = $global:Key
	   $global:EnableMarkdown = $global:true
	   Switch($global:Subreddit)
	   {
		   none {
			   Switch($global:Sort)
			   {
				   random {
					   $global:rSub = Invoke-RestMethod -Uri 'https://reddit.com/random/.json/'
					   $global:Hot = $global:rSub.data.children.data
					   }
			   }
		   }

		   `* {
			   Switch($global:Sort)
			   {
				   random {
					   $global:rSub = Invoke-RestMethod -Uri "https://reddit.com/r/$global:Subreddit/random/.json"
					   $global:Hot = $global:rSub.data.children.data
				   }

				   `* {
					   $global:Amount = 5
					   $global:rSub = Invoke-RestMetho -Uri "https://reddit.com/r/$global:Subreddit/.json?sort=top&t=week&limit=$global:Amount"
					   $global:Hot = $global:rSub.data.$(Get-Random)%$global:Amount.children.data
				   }
			   }
		   }
	   }
	   $global:MediaID = ($global:Hot | Select-String -Pattern "i.redd.it`|imgur`|gfycat" -Raw).url
	   if ($global:MediaID | Select-String -Pattern "gfycat" -Raw)
	   {
		   $global:MediaID = Invoke-RestMethod -Uri $global:MediaID 	# | SED BLA BLA BLA
	   }
	   $global:Permalink = $global:Hot.permalink
	   $global:Title = $global:Hot.title 					# | SED BLA BLA BLA
	   $global:StickerID = $global:Hot.stickied
	   if ($global:Title)
	   {
		   $global:Caption = "`n $global:Title `n link: <a href=`"https://reddit.com$global:Permalink`">$global:Permalink</a>"
	   }
	   if ($global:MediaID)
	   {
		   $global:TextID = $global:Caption
		   Deploy-TGMethod send_message | Out-File -Path /dev/null
	   }
	   elseif ($global:MediaID | Select-String -Pattern "jpg`|png" -Raw)
	   {
		   $global:PhotoID = $global:MediaID
		   Deploy-TGMethod send_photo | Out-File -Path /dev/null
	   }
	   elseif ($global:MediaID | Select-String -Pattern "gif")
	   {
		   $global:AnimationID = $global:MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($global:MediaID | Select-String -Pattern "mp4") -and !(ffprobe "$global:MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $global:AnimationID = $global:MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($global:MediaID | Select-String -Pattern "mp4") -and (ffprobe "$global:MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $global:VideoID = $global:MediaID
		   Deploy-TGMethod send_video | Out-File -Path /dev/null
	   }
   }

   function Invoke-PhotoArray {
	   $global:Obj = @()
	   for ( $global:x = 0; $global:x -le $global:j; $global:x++)
	   {
		   $global:Obj += @{
			   'type' = 'photo'
			   'media' = $global:Media[$global:x]
		   }
	   }
   }

   function Invoke-InLine {
	   param (
	   $global:Arg1
	   )

	   ($global:j -eq "") -and ($global:j = 0)

	   Switch($global:Arg1)
	   {
		   article {
			   for ($global:x = 0; $global:x -le $global:j; $global:x++)
			   {
				   $global:Obj[$global:x] = @{
					   'type' = 'article'
					   'id' = Get-Random
					   'title' = $global:Title[$global:x]
					   'input_message_content' = @{
						   'message_text' = $global:Markdown[0]+$global:MessageText[$global:x]+$global:Markdown[1]
						   'parse_mode' = 'html'
					   }
					   'description' = $global:Description[$global:x]
				   }
			   }
		   }

		   photo {
			   for ($global:x = 0; $global:x -le $global:j; $global:x++)
			   {
				   $global:Obj[$global:x] = @{
					   'type' = 'photo'
					   'id' = Get-Random
					   'photo_url' = $global:PhotoURL[$global:x]
					   'thumb_url' = $global:ThumbURL[$global:x]
					   'caption' = $global:Caption[$global:x]
				   }
			   }
		   }

		   gif {
			   for ($global:x = 0; $global:x -le $global:j; $global:x++)
			   {
				   $global:Obj[$global:x] = @{
					   'type' = 'gif'
					   'id' = Get-Random
					   'gif_url' = $global:GifURL[$global:x]
					   'thumb_url' = $global:ThumbURL[$global:x]
					   'caption' = $global:Caption[$global:x]
				   }
			   }
		   }

		   button {
			   for ($global:x = 0; $global:x -le $global:j; $global:x++)
			   {
				   $global:Obj[$global:x] = @{
					   'text' = $global:ButtonText[$global:x]
					   'callback_data' = $global:ButtonText[$global:x]
				   }
			   }
		   }
	   }
   }

   function Deploy-TGMethod {
	   param (
	   $TGInput
	   )

	   Switch($TGInput)
	   {
		   send_message {
			   # ($global:EnableMarkdown) -and ($global:TextID = roba
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMessage" `
			   -Body @{
				   "chat_id" = $global:ChatID
				   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
				   "reply_markup" = $global:MarkupID
			   	   "text" = "$global:Markdown[0]$global:TextID$global:Markdown[1]"
			   }
		   }

		   send_photo {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendPhoto" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
				   "caption" = $global:Caption
			   	   "photo" = $global:PhotoID
			   }
		   }

		   send_document {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendDocument" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "document" = $global:DocumentID
			   }
		   }


		   send_video {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVideo" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "thumb" = $global:Thumb
			   	   "caption" = $global:Caption
			   	   "video" = $global:VideoID
			   }
		   }

		   send_mediagroup {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMediaGroup" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "media" = $global:MediagroupID
			   }
		   }

		   send_audio {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAudio" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "audio" = $global:AudioID
			   }
		   }

		   send_voice {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVoice" `
			   -Body @{
				   "chat_id" = $global:ChatID
				   "parse_mode" = "html"
				   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "voice" = $global:VoiceID
			   }
		   }

		   send_animation {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAnimation" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "animation" = $global:AnimationID
			   }
		   }

		   send_sticker {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendSticker" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $global:ReplyID
			   	   "caption" = $global:Caption
			   	   "sticker" = $global:StickerID
			   }
		   }

		   send_inline {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body @{
				   "inline_query_id" = $global:InlineID
			   	   "results" = $global:ReturnQuery
			   	   "next_offset" = $global:Offset
			   	   "cache_time" = "0"
			   	   "is_personal" = "true"
			   }
		   }

		   forward_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/forwardMessage" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "from_chat_id" = $global:FromChatID
			   	   "message_id" = $global:ForwardID
			   }
		   }

		   inline_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body @{
				   "inline_query_id" = $global:InlineQueryID
			   	   "results" = $global:ReturnQuery
			   	   "next_offset" = $global:Offset
			   	   "cache_time" = "0"
			   	   "is_personal" = "true" 
			   } | Out-File -Path /dev/null
		   }

		   button_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerCallbackQuery" `
			   -Body @{
				   "callback_query_id" = $global:CallbackID
			   	   "text" = $global:ButtonTextReply
			   }
		   }

		   edit_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/editMessageText" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "message_id" = $global:ToEditID
			   	   "text" = $global:EditText
			   }
		   }

		   delete_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/deleteMessage" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "message_id" = $global:ToDeleteID
			   	   "text" = $global:EditText
			   }
		   }

		   copy_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/copyMessage" `
			   -Body @{
				   "chat_id" = $global:ChatID
			   	   "from_chat_id" = $global:FromChatID
			   	   "message_id" = $global:MessageID
			   }
		   }

		   set_chat_permissions {
			   Invoke-RestMethod -Uri "$TelegramAPI/setChatPermissions" 
			   -Body @{
				   "chat_id" = $global:ChatID
				   "permissions" = @{
					   "can_send_messages" = $global:CanSendMessages
					   "can_send_media_messages" = $global:CanSendMediaMessages
					   "can_send_other_messages" = $global:CanSendOtherMessages
					   "can_send_polls" = $global:CanSendPolls
					   "can_add_web_pages_previews" = $global:CanAddWebPagesPreviews
				   }
		   	   }
		   }

		   leave_chat {
			   Invoke-RestMethod -Uri "$TelegramAPI/leaveChat" 
			   -Body @{
				   "chat_id" = $global:ChatID
			   }
		   }

		   get_me {
			   Invoke-RestMethod -Uri "$TelegramAPI/getMe"
		   }
	   }
   }

   function Get-FileType {
	   param (
	   $TGInput
	   )

	   ($TGInput -eq "reply") -and ($global:Message = $global:ReplyToMessage)
	   $global:TextID = $global:Message.text
	   $global:PhotoID = $global:Message.photo."0".file_id
	   $global:AnimationID = $global:Message.animation.file_id
	   $global:VideoID = $global:Message.video.file_id
	   $global:StickerID = $global:Message.sticket.file_id
	   $global:AudioID = $global:Message.audio.file_id
	   $global:VoiceID = $global:Message.voice.file_id
	   $global:DocumentID = $global:Message.document.file_id

	   if ($global:TextID)
	   {
		   if (!(Test-Path -Path botinfo -PathType Leaf))
		   {
			   Deploy-TGMethod get_me | ConvertTo-Json | Out-File -Path botinfo
		   }
		   # $global:TextID = (Get-Content -Path botinfo | ConvertFrom-Json).result[0].username
		   $global:FileType = "text"
	   }

	   if ($global:StickerID)
	   {
		   $global:FileType = 'sticker'
	   }

	   if ($global:AnimationID)
	   {
		   $global:FileType = 'animation'
	   }

	   if ($global:PhotoID)
	   {
		   $global:FileType = 'photo'
	   }

	   if ($global:VideoID)
	   {
		   $global:FileType = 'video'
	   }

	   if ($global:AudioID)
	   {
		   $global:FileType = 'audio'
	   }

	   if ($global:VoiceID)
	   {
		   $global:FileType = 'voice'
	   }

	   if ($global:DocumentID)
	   {
		   $global:FileType = 'document'
	   }
   }

   function Get-NormalReply {
	   Switch($global:FirstNormal)
	   {
		   $global:PF'start' {
			   $global:TextID = "This is a PowerShell Bot, use /source to download."
			   $global:ReplyID = $global:MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $global:PF'source' {
			   $global:TextID = "Download PowerShell Bot source from <https://github.com/adamantinum/PSTelegramBot>"
			   $global:ReplyID = $global:MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $global:PF'help' {
			   $global:TextID = Get-Content -Path README.md
			   $global:ReplyID = $global:MessageID
			   Deploy-TGMethod send_message | Out-File -path /dev/null
		   }
	   }
   }

   function Get-Inlinereply {
	   Switch($global:Result)
	   {
		   'ok' {
			   $global:Title = 'Ok'
			   $global:MessageText = 'Ok'
			   $global:Description = 'Alright'
			   $global:ReturnQuery = Invoke-InLine article
			   Deploy-TGMethod send_inline | Out-File -Path /dev/null
		   }
	   }
   }

   function Get-ButtonReply {
	   Switch($global:CallbackMessageText)
	   {
		   test {
			   $global:TextID = $global:CallbackData
			   Deploy-TGMethod button_reply | Out-File -Path /dev/null
			   $global:ChatID = $global:CallbackUserID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Invoke-ProcessReply {
	   $global:Message = ($TGInput | ConvertFrom-Json).result[0].message
	   $global:Inline = ($TGInput | ConvertFrom-Json).result[0].inline_query
	   $global:Callback = ($TGInput | ConvertFrom-Json).result[0].callback_query
	   $global:FileType = $global:Message.chat.type
	   if (!$global:Message.text -and ($global:FileType -ne "private") -and !$global:Inline -and !$global:Callback)
	   {
		   return
	   }

	   # User database
	   $global:UsernameTag = $global:Message.from.username
	   $global:UsernameID = $global:Message.from.id
	   $global:UsernameFirstName = $global:Message.from.first_name
	   $global:UsernameLastName = $global:Messange.from.last_name
	   if ($global:UsernameID)
	   {
		   !(Test-Path -Path db/users -PathType Container) -and (New-Item -Name db/users/ -ItemType Directory)
		   $global:FileUser = "db/users/$global:UsernameTag"
		   if (!(Test-Path -Path $global:FileUser -PathType Leaf))
		   {
			   (!$global:UsernameTag) -and ($global:UsernameTag = "(empty)")
			   @{
				   'tag' = $global:UsernameTag
				   'id' = $global:UsernameID
				   'fname' = $global:UsernameFirstName
				   'lname' = $global:UsernameLastName
			   } | ConvertTo-Json | Out-File -Path $global:FileUser
		   }
		   
		   if ("tag: $global:UsernameTag" -ne (Select-String -LiteralPath $global:FileUser -Pattern "tag" -Raw))
		   {
			   $global:FileUser = $global:FileUser -replace "tag: .*", "tag :$global:UsernameTag"
		   }

		   if ("fname: $global:UsernameFirstName" -ne (Select-String -LiteralPath $global:FileUser -Pattern "fname" -Raw))
		   {
			   $global:FileUser = $global:FileUser -replace "fname: .*", "fname: $global:UsernameFirstName"
		   }

		   if ("lname: $global:UsernameLastName" -ne (Select-String -LiteralPath $global:FileUser -Pattern "lname" -Raw))
		   {
			   $global:FileUser = $global:FileUser -replace "lname: .*", "lname: $global:UsernameLastName"
		   }
	   }
	   $global:ReplyToMessage = $global:Message.reply_to_message
	   if ($global:ReplyToMessage)
	   {
		   $global:ReplyToID = $global:ReplyToMessage.message_id
		   $global:ReplyToUserID = $global:ReplyToMessage.from.id
		   $global:ReplyToUserTag = $global:ReplyToMessage.from.username
		   $global:ReplyToUserFirstName = $global:ReplyToMessage.from.first_name
		   $global:ReplyToUserLastName = $global:ReplyToMessage.from.last_name
		   $global:ReplyToText = $global:ReplyToMessage.text
		   !(Test-Path -Path db/users -PathType Container) -and (New-Item -Name db/users/ -ItemType Directory)
		   $global:FileReplyUser = "db/users/$global:ReplyToUserTag"
		   if (Test-Path -Path $global:FileReplyUser -PathType Leaf)
		   {
			   (!$global:ReplyToUserTag) -and ($global:ReplyToUserTag = "(empty)")
			   @{
				   'tag' = $global:ReplyToUserTag
				   'id' = $global:ReplyToUserID
				   'fname' = $global:ReplyToUserFirstName
				   'lname' = $global:ReplyToUserLastName
			   } | ConvertTo-Json | Out-File -Path $global:FileReplyUser
		   }
	   }

	   # Chat database
	   $global:ChatTitle = $global:Message.chat.title
	   $global:ChatID = $global:Message.chat.id
	   if ($global:ChatTitle)
	   {
		   !(Test-Path -Path db/chats -PathType Container) -and (New-item -Name db/chats -ItemType Directory)
		   $global:FileChat = "db/chats/$global:ChatID"
		   if (!(Test-Path -Path $global:FileChat -PathType Leaf))
		   {
			   @{
				   'title' = $global:ChatTitle
				   'id' = $global:ChatID
				   'type' = $global:FileType
			   } | ConvertTo-Json | Out-File -Path $global:FileChat
		   }
	   }

	   $global:CallBackUser = $global:Callback.from.username
	   $global:CallbackUserID = $global:Callback.from.id
	   $global:CallbackID = $global:Callback.id
	   $global:CallbackData = $global:Callback.data
	   $global:CallbackMessageText = $global:Callback.message.text

	   if ( $global:FileType -eq "private" -or $global:Inline -or $global:Callback)
	   {
		   $global:BotChatDir = "db/bot_chats"
		   $global:BotChatUserID = $global:UsernameID
	   }
	   else
	   {
		   $global:BotChatID = "db/bot_group_chats"
		   $global:BotChatUserID = $global:ChatID
	   }

	   $global:MessageID = $global:Message.message_id
	   $global:InlineUser = $global:Inline.from.username
	   $global:InlineUserID = $global:Inline.from.id
	   $global:InlineID = $global:Inline.id
	   $global:Results = $global:Inline.query

	   Get-FileType

	   Switch ($global:FileType)
	   {
		   text {
			   $global:FirstNormal = $global:TextID
		   }
		   
		   photo {
			   $global:FirstNormal = $global:PhotoID
		   }
		   
		   animation {
			   $global:FirstNormal = $global:AnimationID
		   }
		   
		   video {
			   $global:FirstNormal = $global:VideoID
		   }
		   
		   audio {
			   $global:FirstNormal = $global:AudioID
		   }

		   voice {
			   $global:FirstNormal = $global:VoiceID
		   }

		   document {
			   $global:FirstNormal = $global:DocumentID
		   }
	   }

	   $global:PF = $global:TextID.ToCharArray() | select -First 1
	   
	   if ( $global:PF -ne '!' -and $global:PF -ne '/')
	   {
		   $global:PF = ""
	   }

	   if ($global:FirstNormal)
	   {
		   Get-NormalReply
		   # source?
	   }
	   elseif ($global:Results)
	   {
		   Get-Inlinereply
		   # source?
	   }
	   elseif ($global:CallbackData)
	   {
		   Get-ButtonReply
		   # source?
	   }
   }

   Invoke-ProcessReply

   $EndTime = Get-Date -UFormat %s

   Write-Host "[$(Get-Date -UFormat "%F %H:%M:%s")] elapsed time: $($global:EndTime-$global:StartTime) ms"

   Set-PSDebug -Off
} 2>&1 5>&1 >> "log.log" 
