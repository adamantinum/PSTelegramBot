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

   if (Test-Path -Path variable:/PSDebugContext)
   {
	   Set-PSDebug -Trace 2
   }

   function Invoke-Sth {
	   param ( 
	   $Global:Arg1,
	   $Global:Arg2
	   )

	   Switch($Global:Arg1)
	   {
		   1 {
			   $Global:TextID = "processing..."
			   $Global:ProcessingID = (Deploy-TGMethod send_message).result[0].message_id
		   }

		   2 {
			   $Global:ToEditID = $Global:ProcessingID
			   $Global:EditText = "sending..."
			   $Global:EditedID = (Deploy-TGMethod edit_message).result[0].message_id
		   }

		   3 {
			   $Global:ToDeleteID = $Global:EditionID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }

		   value {
			   $Global:ToEditID = $Global:ProcessingID
			   $Global:EditText = $Global:Arg2
			   $Global:ProcessingID = (Deploy-TGMethod edit_message).result[0].message_id
		   }

		   error {
			   $Global:ToDeleteID = $Global:ProcessingID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Find-Subreddit {
	   param (
	   $TGInput,
	   $Global:Key
	   )

	   $Global:Subreddit = $TGInput
	   $Global:Sort = $Global:Key
	   $Global:EnableMarkdown = $true
	   Switch($Global:Subreddit)
	   {
		   none {
			   Switch($Global:Sort)
			   {
				   random {
					   $Global:rSub = Invoke-RestMethod -Uri 'https://reddit.com/random/.json/'
					   $Global:Hot = $Global:rSub.data.children.data
					   }
			   }
		   }

		   `* {
			   Switch($Global:Sort)
			   {
				   random {
					   $Global:rSub = Invoke-RestMethod -Uri "https://reddit.com/r/$Global:Subreddit/random/.json"
					   $Global:Hot = $Global:rSub.data.children.data
				   }

				   `* {
					   $Global:Amount = 5
					   $Global:rSub = Invoke-RestMetho -Uri "https://reddit.com/r/$Global:Subreddit/.json?sort=top&t=week&limit=$Global:Amount"
					   $Global:Hot = $Global:rSub.data.$(Get-Random)%$Global:Amount.children.data
				   }
			   }
		   }
	   }
	   $Global:MediaID = ($Global:Hot | Select-String -Pattern "i.redd.it`|imgur`|gfycat" -Raw).url
	   if ($Global:MediaID | Select-String -Pattern "gfycat" -Raw)
	   {
		   $Global:MediaID = Invoke-RestMethod -Uri $Global:MediaID 	# | SED BLA BLA BLA
	   }
	   $Global:Permalink = $Global:Hot.permalink
	   $Global:Title = $Global:Hot.title 					# | SED BLA BLA BLA
	   $Global:StickerID = $Global:Hot.stickied
	   if ($Global:Title)
	   {
		   $Global:Caption = "`n $Global:Title `n link: <a href=`"https://reddit.com$Global:Permalink`">$Global:Permalink</a>"
	   }
	   if ($Global:MediaID)
	   {
		   $Global:TextID = $Global:Caption
		   Deploy-TGMethod send_message | Out-File -Path /dev/null
	   }
	   elseif ($Global:MediaID | Select-String -Pattern "jpg`|png" -Raw)
	   {
		   $Global:PhotoID = $Global:MediaID
		   Deploy-TGMethod send_photo | Out-File -Path /dev/null
	   }
	   elseif ($Global:MediaID | Select-String -Pattern "gif")
	   {
		   $Global:AnimationID = $Global:MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($Global:MediaID | Select-String -Pattern "mp4") -and !(ffprobe "$Global:MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $Global:AnimationID = $Global:MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($Global:MediaID | Select-String -Pattern "mp4") -and (ffprobe "$Global:MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $Global:VideoID = $Global:MediaID
		   Deploy-TGMethod send_video | Out-File -Path /dev/null
	   }
   }

   function Invoke-PhotoArray {
	   $Global:Obj = @()
	   for ( $Global:x = 0; $Global:x -le $Global:j; $Global:x++)
	   {
		   $Global:Obj += @{
			   'type' = 'photo'
			   'media' = $Global:Media[$Global:x]
		   }
	   }
   }

   function Invoke-InLine {
	   param (
	   $Arg1
	   )

	   ($Global:j -eq "") -and ($Global:j = 0)

	   Switch($Arg1)
	   {
		   article {
			   for ($x = 0; $x -le $j; $x++)
			   {
				   $Global:Obj[$x] = @{
					   'type' = 'article'
					   'id' = Get-Random
					   'title' = $Global:Title[$x]
					   'input_message_content' = @{
						   'message_text' = $Global:Markdo
						   'parse_mode' = 'html'
					   }
					   'description' = $Global:Description[$x]
				   }
			   }
		   }

		   photo {
			   for ($x = 0; $x -le $Global:j; $x++)
			   {
				   $Global:Obj[$x] = @{
					   'type' = 'photo'
					   'id' = Get-Random
					   'photo_url' = $Global:PhotoURL[$x]
					   'thumb_url' = $Global:ThumbURL[$x]
					   'caption' = $Global:Caption[$x]
				   }
			   }
		   }

		   gif {
			   for ($x = 0; $x -le $Global:j; $x++)
			   {
				   $Global:Obj[$x] = @{
					   'type' = 'gif'
					   'id' = Get-Random
					   'gif_url' = $Global:GifURL[$x]
					   'thumb_url' = $Global:ThumbURL[$x]
					   'caption' = $Global:Caption[$x]
				   }
			   }
		   }

		   button {
			   for ($x = 0; $x -le $Global:j; $x++)
			   {
				   $Global:Obj[$x] = @{
					   'text' = $Global:ButtonText[$x]
					   'callback_data' = $Global:ButtonText[$x]
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
			   # ($Global:EnableMarkdown) -and ($Global:TextID = roba
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMessage" `
			   -Body @{
				   "chat_id" = $Global:ChatID
				   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
				   "reply_markup" = $Global:MarkupID
			   	   "text" = $Global:Markdown[0]+$Global:TextID.Replace('<','').Replace('>','')+$Global:Markdown[1]
			   }
		   }

		   send_photo {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendPhoto" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
				   "caption" = $Global:Caption
			   	   "photo" = $Global:PhotoID
			   }
		   }

		   send_document {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendDocument" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "document" = $Global:DocumentID
			   }
		   }


		   send_video {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVideo" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "thumb" = $Global:Thumb
			   	   "caption" = $Global:Caption
			   	   "video" = $Global:VideoID
			   }
		   }

		   send_mediagroup {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMediaGroup" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "media" = $Global:MediagroupID
			   }
		   }

		   send_audio {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAudio" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "audio" = $Global:AudioID
			   }
		   }

		   send_voice {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVoice" `
			   -Body @{
				   "chat_id" = $Global:ChatID
				   "parse_mode" = "html"
				   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "voice" = $Global:VoiceID
			   }
		   }

		   send_animation {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAnimation" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "animation" = $Global:AnimationID
			   }
		   }

		   send_sticker {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendSticker" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "parse_mode" = "html"
			   	   "reply_to_message_id" = $Global:ReplyID
			   	   "caption" = $Global:Caption
			   	   "sticker" = $Global:StickerID
			   }
		   }

		   send_inline {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body @{
				   "inline_query_id" = $Global:InlineID
			   	   "results" = $Global:ReturnQuery
			   	   "next_offset" = $Global:Offset
			   	   "cache_time" = "0"
			   	   "is_personal" = "true"
			   }
		   }

		   forward_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/forwardMessage" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "from_chat_id" = $Global:FromChatID
			   	   "message_id" = $Global:ForwardID
			   }
		   }

		   inline_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body @{
				   "inline_query_id" = $Global:InlineQueryID
			   	   "results" = $Global:ReturnQuery
			   	   "next_offset" = $Global:Offset
			   	   "cache_time" = "0"
			   	   "is_personal" = "true" 
			   } | Out-File -Path /dev/null
		   }

		   button_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerCallbackQuery" `
			   -Body @{
				   "callback_query_id" = $Global:CallbackID
			   	   "text" = $Global:ButtonTextReply
			   }
		   }

		   edit_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/editMessageText" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "message_id" = $Global:ToEditID
			   	   "text" = $Global:EditText
			   }
		   }

		   delete_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/deleteMessage" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "message_id" = $Global:ToDeleteID
			   	   "text" = $Global:EditText
			   }
		   }

		   copy_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/copyMessage" `
			   -Body @{
				   "chat_id" = $Global:ChatID
			   	   "from_chat_id" = $Global:FromChatID
			   	   "message_id" = $Global:MessageID
			   }
		   }

		   set_chat_permissions {
			   Invoke-RestMethod -Uri "$TelegramAPI/setChatPermissions" 
			   -Body @{
				   "chat_id" = $Global:ChatID
				   "permissions" = @{
					   "can_send_messages" = $Global:CanSendMessages
					   "can_send_media_messages" = $Global:CanSendMediaMessages
					   "can_send_other_messages" = $Global:CanSendOtherMessages
					   "can_send_polls" = $Global:CanSendPolls
					   "can_add_web_pages_previews" = $Global:CanAddWebPagesPreviews
				   }
		   	   }
		   }

		   leave_chat {
			   Invoke-RestMethod -Uri "$TelegramAPI/leaveChat" 
			   -Body @{
				   "chat_id" = $Global:ChatID
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

	   ($TGInput -eq "reply") -and ($Global:Message = $Global:ReplyToMessage)
	   $Global:TextID = $Global:Message.text
	   $Global:PhotoID = $Global:Message.photo."0".file_id
	   $Global:AnimationID = $Global:Message.animation.file_id
	   $Global:VideoID = $Global:Message.video.file_id
	   $Global:StickerID = $Global:Message.sticket.file_id
	   $Global:AudioID = $Global:Message.audio.file_id
	   $Global:VoiceID = $Global:Message.voice.file_id
	   $Global:DocumentID = $Global:Message.document.file_id

	   if ($Global:TextID)
	   {
		   if (!(Test-Path -Path botinfo -PathType Leaf))
		   {
			   Deploy-TGMethod get_me | ConvertTo-Json | Out-File -Path botinfo
		   }
		   # $Global:TextID = (Get-Content -Path botinfo | ConvertFrom-Json).username
		   $Global:FileType = "text"
	   }

	   if ($Global:StickerID)
	   {
		   $Global:FileType = 'sticker'
	   }

	   if ($Global:AnimationID)
	   {
		   $Global:FileType = 'animation'
	   }

	   if ($Global:PhotoID)
	   {
		   $Global:FileType = 'photo'
	   }

	   if ($Global:VideoID)
	   {
		   $Global:FileType = 'video'
	   }

	   if ($Global:AudioID)
	   {
		   $Global:FileType = 'audio'
	   }

	   if ($Global:VoiceID)
	   {
		   $Global:FileType = 'voice'
	   }

	   if ($Global:DocumentID)
	   {
		   $Global:FileType = 'document'
	   }
   }

   function Get-NormalReply {
	   Switch($Global:FirstNormal)
	   {
		   $Global:PF'start' {
			   $Global:TextID = "`r`nThis is a PowerShell Bot, use /source to download.`r`n"
			   $Global:ReplyID = $Global:MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $Global:PF'source' {
			   $Global:TextID = 'Download PowerShell Bot source from https://github.com/adamantinum/PSTelegramBot'
			   $Global:ReplyID = $Global:MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $Global:PF'help' {
			   $Global:TextID = [string](Get-Content -LiteralPath README.md)
			   $Global:ReplyID = $Global:MessageID
			   Deploy-TGMethod send_message | Out-File -path /dev/null
		   }
	   }
   }

   function Get-Inlinereply {
	   Switch($Global:Result)
	   {
		   'ok' {
			   $Global:Title = 'Ok'
			   $Global:MessageText = 'Ok'
			   $Global:Description = 'Alright'
			   $Global:ReturnQuery = Invoke-InLine article
			   Deploy-TGMethod send_inline | Out-File -Path /dev/null
		   }
	   }
   }

   function Get-ButtonReply {
	   Switch($Global:CallbackMessageText)
	   {
		   test {
			   $Global:TextID = $Global:CallbackData
			   Deploy-TGMethod button_reply | Out-File -Path /dev/null
			   $Global:ChatID = $Global:CallbackUserID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Invoke-ProcessReply {
	   $Global:Message = $TGInput.message
	   $Global:Inline = $TGInput.inline_query
	   $Global:Callback = $TGInput.callback_query
	   $Global:FileType = $Global:Message.chat.type
	   if (!$Global:Message.text -and ($Global:FileType -ne "private") -and !$Global:Inline -and !$Global:Callback)
	   {
		   return
	   }

	   # User database
	   $Global:UsernameTag = $Global:Message.from.username
	   $Global:UsernameID = $Global:Message.from.id
	   $Global:UsernameFirstName = $Global:Message.from.first_name
	   $Global:UsernameLastName = $Global:Messange.from.last_name

	   $Global:Markdown = @()
	   if ($Global:UsernameID)
	   {
		   !(Test-Path -Path db/users -PathType Container) -and (New-Item -Name db/users/ -ItemType Directory)
		   $Global:FileUser = "db/users/$Global:UsernameTag"
		   if (!(Test-Path -Path $Global:FileUser -PathType Leaf))
		   {
			   (!$Global:UsernameTag) -and ($Global:UsernameTag = "(empty)")
			   @{
				   'tag' = $Global:UsernameTag
				   'id' = $Global:UsernameID
				   'fname' = $Global:UsernameFirstName
				   'lname' = $Global:UsernameLastName
			   } | ConvertTo-Json | Out-File -Path $Global:FileUser
		   }
		   
		   if ("tag: $Global:UsernameTag" -ne (Select-String -LiteralPath $Global:FileUser -Pattern "tag" -Raw))
		   {
			   $Global:FileUser = $Global:FileUser -replace "tag: .*", "tag :$Global:UsernameTag"
		   }

		   if ("fname: $Global:UsernameFirstName" -ne (Select-String -LiteralPath $Global:FileUser -Pattern "fname" -Raw))
		   {
			   $Global:FileUser = $Global:FileUser -replace "fname: .*", "fname: $Global:UsernameFirstName"
		   }

		   if ("lname: $Global:UsernameLastName" -ne (Select-String -LiteralPath $Global:FileUser -Pattern "lname" -Raw))
		   {
			   $Global:FileUser = $Global:FileUser -replace "lname: .*", "lname: $Global:UsernameLastName"
		   }
	   }
	   $Global:ReplyToMessage = $Global:Message.reply_to_message
	   if ($Global:ReplyToMessage)
	   {
		   $Global:ReplyToID = $Global:ReplyToMessage.message_id
		   $Global:ReplyToUserID = $Global:ReplyToMessage.from.id
		   $Global:ReplyToUserTag = $Global:ReplyToMessage.from.username
		   $Global:ReplyToUserFirstName = $Global:ReplyToMessage.from.first_name
		   $Global:ReplyToUserLastName = $Global:ReplyToMessage.from.last_name
		   $Global:ReplyToText = $Global:ReplyToMessage.text
		   !(Test-Path -Path db/users -PathType Container) -and (New-Item -Name db/users/ -ItemType Directory)
		   $Global:FileReplyUser = "db/users/$Global:ReplyToUserTag"
		   if (Test-Path -Path $Global:FileReplyUser -PathType Leaf)
		   {
			   (!$Global:ReplyToUserTag) -and ($Global:ReplyToUserTag = "(empty)")
			   @{
				   'tag' = $Global:ReplyToUserTag
				   'id' = $Global:ReplyToUserID
				   'fname' = $Global:ReplyToUserFirstName
				   'lname' = $Global:ReplyToUserLastName
			   } | ConvertTo-Json | Out-File -Path $Global:FileReplyUser
		   }
	   }

	   # Chat database
	   $Global:ChatTitle = $Global:Message.chat.title
	   $Global:ChatID = $Global:Message.chat.id
	   if ($Global:ChatTitle)
	   {
		   !(Test-Path -Path db/chats -PathType Container) -and (New-item -Name db/chats -ItemType Directory)
		   $Global:FileChat = "db/chats/$Global:ChatID"
		   if (!(Test-Path -Path $Global:FileChat -PathType Leaf))
		   {
			   @{
				   'title' = $Global:ChatTitle
				   'id' = $Global:ChatID
				   'type' = $Global:FileType
			   } | ConvertTo-Json | Out-File -Path $Global:FileChat
		   }
	   }

	   $Global:CallBackUser = $Global:Callback.from.username
	   $Global:CallbackUserID = $Global:Callback.from.id
	   $Global:CallbackID = $Global:Callback.id
	   $Global:CallbackData = $Global:Callback.data
	   $Global:CallbackMessageText = $Global:Callback.message.text

	   if ( $Global:FileType -eq "private" -or $Global:Inline -or $Global:Callback)
	   {
		   $Global:BotChatDir = "db/bot_chats"
		   $Global:BotChatUserID = $Global:UsernameID
	   }
	   else
	   {
		   $Global:BotChatID = "db/bot_group_chats"
		   $Global:BotChatUserID = $Global:ChatID
	   }

	   $Global:MessageID = $Global:Message.message_id
	   $Global:InlineUser = $Global:Inline.from.username
	   $Global:InlineUserID = $Global:Inline.from.id
	   $Global:InlineID = $Global:Inline.id
	   $Global:Results = $Global:Inline.query

	   Get-FileType

	   Switch ($Global:FileType)
	   {
		   text {
			   $Global:FirstNormal = $Global:TextID
		   }
		   
		   photo {
			   $Global:FirstNormal = $Global:PhotoID
		   }
		   
		   animation {
			   $Global:FirstNormal = $Global:AnimationID
		   }
		   
		   video {
			   $Global:FirstNormal = $Global:VideoID
		   }
		   
		   audio {
			   $Global:FirstNormal = $Global:AudioID
		   }

		   voice {
			   $Global:FirstNormal = $Global:VoiceID
		   }

		   document {
			   $Global:FirstNormal = $Global:DocumentID
		   }
	   }

	   $Global:PF = $Global:TextID.ToCharArray() | select -First 1
	   
	   if ( $Global:PF -ne '!' -and $Global:PF -ne '/')
	   {
		   $Global:PF = ""
	   }

	   if ($Global:FirstNormal)
	   {
		   Get-NormalReply
		   # source?
	   }
	   elseif ($Global:Results)
	   {
		   Get-Inlinereply
		   # source?
	   }
	   elseif ($Global:CallbackData)
	   {
		   Get-ButtonReply
		   # source?
	   }
   }

   Invoke-ProcessReply

   $EndTime = Get-Date -UFormat %s

   Write-Host "[$(Get-Date -UFormat "%F %H:%M:%s")] elapsed time: $($Global:EndTime-$Global:StartTime) ms"

   Set-PSDebug -Off
} 2>&1 5>&1 >> "log.log" 
