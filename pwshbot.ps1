#!/usr/bin/pwsh

$StartTime = Get-Date -UFormat %s

function prompt {
	$(if (Test-Path -Path variable:/PSDebugContext) { "[$(Get-Date -UFormat "%F %H:%M:%s")]" })
}

$Token = Get-Content -Path token
$TelegramAPI = "https://api.telegram.org/bot$Token"

&{
   Set-PSDebug -Strict
   
   function Invoke-Sth {
	   param ( 
	   $Arg1,
	   $Arg2
	   )

	   Switch($Arg1)
	   {
		   1 {
			   $TextID = "processing..."
			   $ProcessingID = (Deploy-TGMethod send_message).result.message_id
		   }

		   2 {
			   $ToEditID = $ProcessingID
			   $EditText = "sending..."
			   $EditedID = (Deploy-TGMethod edit_message).result.message_id
		   }

		   3 {
			   $ToDeleteID = $EditionID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }

		   value {
			   $ToEditID = $ProcessingID
			   $EditText = $Arg2
			   $ProcessingID = (Deploy-TGMethod edit_message).result.message_id
		   }

		   error {
			   $ToDeleteID = $ProcessingID
			   Deploy-TGMethod delete_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Find-Subreddit {
	   param (
	   $TGInput,
	   $Key
	   )

	   $Subreddit = $TGInput
	   $Sort = $Key
	   $EnableMarkdown = $true
	   Switch($Subreddit)
	   {
		   none {
			   Switch($Sort)
			   {
				   random {
					   $rSub = (Invoke-WebRequest -Uri 'https://reddit.com/random/.json/').Content
					   $Hot = ($rSub | ConvertFrom-Json).data.children.data
					   }
			   }
		   }

		   `* {
			   Switch($Sort)
			   {
				   random {
					   $rSub = (Invoke-WebRequest -Uri "https://reddit.com/r/$Subreddit/random/.json").Content
					   $Hot = ($rSub | ConvertFrom-Json).data.children.data
				   }

				   `* {
					   $Amount = 5
					   $rSub = (Invoke-WebRequest -Uri "https://reddit.com/r/$Subreddit/.json?sort=top&t=week&limit=$Amount").Content
					   $Hot = ($rSub | ConvertFrom-Json).data.$(Get-Random)%$Amount.children.data
				   }
			   }
		   }
	   }
	   $MediaID = ($Hot | Select-String -Pattern "i.redd.it`|imgur`|gfycat" -Raw).url
	   if ($MediaID | Select-String -Pattern "gfycat" -Raw)
	   {
		   $MediaID = Invoke-RestMethod -Uri $MediaID 	# | SED BLA BLA BLA
	   }
	   $Permalink = $Hot.permalink
	   $Title = $Hot.title 					# | SED BLA BLA BLA
	   $StickerID = $Hot.stickied
	   if ($Title)
	   {
		   $Caption = "`n $Title `n link: <a href=`"https://reddit.com$Permalink`">$Permalink</a>"
	   }
	   if ($MediaID)
	   {
		   $TextID = $Caption
		   Deploy-TGMethod send_message | Out-File -Path /dev/null
	   }
	   elseif ($MediaID | Select-String -Pattern "jpg`|png" -Raw)
	   {
		   $PhotoID = $MediaID
		   Deploy-TGMethod send_photo | Out-File -Path /dev/null
	   }
	   elseif ($MediaID | Select-String -Pattern "gif")
	   {
		   $AnimationID = $MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($MediaID | Select-String -Pattern "mp4") -and !(ffprobe "$MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $AnimationID = $MediaID
		   Deploy-TGMethod send_animation | Out-File -Path /dev/null
	   }
	   elseif (($MediaID | Select-String -Pattern "mp4") -and (ffprobe "$MediaID" 2>&1 | Select-String -Pattern 'Audio:' -Quiet))
	   {
		   $VideoID = $MediaID
		   Deploy-TGMethod send_video | Out-File -Path /dev/null
	   }
   }

   function Invoke-PhotoArray {
	   $Obj = @()
	   for ( $x = 0; $x -le $j; $x++)
	   {
		   $Obj += @{
			   'type' = 'photo'
			   'media' = $Media[$x]
		   }
	   }
   }

   function Invoke-InLine {
	   param (
	   $Arg1
	   )

	   ($j -eq "") -and ($j = 0)

	   Switch($Arg1)
	   {
		   article {
			   for ($x = 0; $x -le $j; $x++)
			   {
				   $Obj[$x] = @{
					   'type' = 'article'
					   'id' = Get-Random
					   'title' = $Title[$x]
					   'input_message_content' = @{
						   'message_text' = $Markdown[0]+$MessageText[$x]+$Markdown[1]
						   'parse_mode' = 'html'
					   }
					   'description' = $Description[$x]
				   }
			   }
		   }

		   photo {
			   for ($x = 0; $x -le $j; $x++)
			   {
				   $Obj[$x] = @{
					   'type' = 'photo'
					   'id' = Get-Random
					   'photo_url' = $PhotoURL[$x]
					   'thumb_url' = $ThumbURL[$x]
					   'caption' = $Caption[$x]
				   }
			   }
		   }

		   gif {
			   for ($x = 0; $x -le $j; $x++)
			   {
				   $Obj[$x] = @{
					   'type' = 'gif'
					   'id' = Get-Random
					   'gif_url' = $GifURL[$x]
					   'thumb_url' = $ThumbURL[$x]
					   'caption' = $Caption[$x]
				   }
			   }
		   }

		   button {
			   for ($x = 0; $x -le $j; $x++)
			   {
				   $Obj[$x] = @{
					   'text' = $ButtonText[$x]
					   'callback_data' = $ButtonText[$x]
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
			   # ($EnableMarkdown) -and ($TextID = roba
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMessage" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "reply_markup=$MarkupID", `
			   "text=$Markdown[0]$TextID$Markdown[1]"
		   }

		   send_photo {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendPhoto" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "photo=$PhotoID"
		   }

		   send_document {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendDocument" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "document=$DocumentID"
		   }


		   send_video {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVideo" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "thumb=$Thumb", `
			   "caption=$Caption", `
			   "video=$VideoID"
		   }

		   send_mediagroup {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendMediaGroup" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "media=$MediagroupID"
		   }

		   send_audio {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAudio" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "audio=$AudioID"
		   }

		   send_voice {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendVoice" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "voice=$VoiceID"
		   }

		   send_animation {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendAnimation" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "animation=$AnimationID"
		   }

		   send_sticker {
			   Invoke-RestMethod -Uri "$TelegramAPI/sendSticker" `
			   -Body "chat_id=$ChatID", `
			   "parse_mode=html", `
			   "reply_to_message_id=$ReplyID", `
			   "caption=$Caption", `
			   "sticker=$StickerID"
		   }

		   send_inline {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body "inline_query_id=$InlineID", `
			   "results=$ReturnQuery", `
			   "next_offset=$Offset", `
			   "cache_time=0", `
			   "is_personal=true"
		   }

		   forward_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/forwardMessage" `
			   -Body "chat_id=$ChatID", `
			   "from_chat_id=$FromChatID", `
			   "message_id=$ForwardID"
		   }

		   inline_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerInlineQuery" `
			   -Body "inline_query_id=$InlineQueryID", `
			   "results=$ReturnQuery", `
			   "next_offset=$Offset", `
			   "cache_time=0", `
			   "is_personal=true" | Out-File -Path /dev/null
		   }

		   button_reply {
			   Invoke-RestMethod -Uri "$TelegramAPI/answerCallbackQuery" `
			   -Body "callback_query_id=$CallbackID", `
			   "text=$ButtonTextReply"
		   }

		   edit_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/editMessageText" `
			   -Body "chat_id=$ChatID", `
			   "message_id=$ToEditID", `
			   "text=$EditText"
		   }

		   delete_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/deleteMessage" `
			   -Body "chat_id=$ChatID", `
			   "message_id=$ToDeleteID", `
			   "text=$EditText"
		   }

		   copy_message {
			   Invoke-RestMethod -Uri "$TelegramAPI/copyMessage" `
			   -Body "chat_id=$ChatID", `
			   "from_chat_id=$FromChatID", `
			   "message_id=$MessageID"
		   }

		   set_chat_permissions {
			   $Body = @{
				   "chat_id" = $ChatID
				   "permissions" = @{
					   "can_send_messages" = $CanSendMessages
					   "can_send_media_messages" = $CanSendMediaMessages
					   "can_send_other_messages" = $CanSendOtherMessages
					   "can_send_polls" = $CanSendPolls
					   "can_add_web_pages_previews" = $CanAddWebPagesPreviews
				   }
			   }
			   Invoke-RestMethod -Uri "$TelegramAPI/setChatPermissions" -Body ($Body | ConvertTo-Json)
		   }

		   leave_chat {
			   Invoke-RestMethod -Uri "$TelegramAPI/leaveChat" -Body "chat_id=$ChatID"
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

	   ($TGInput -eq "reply") -and $Message = $ReplyToMessage
	   $TextID = $Message.text
	   $PhotoID = $Message.photo."0".file_id
	   $AnimationID = $Message.animation.file_id
	   $VideoID = $Message.video.file_id
	   $StickerID = $Message.sticket.file_id
	   $AudioID = $Message.audio.file_id
	   $VoiceID = $Message.voice.file_id
	   $DocumentID = $Message.document.file_id

	   if ($TextID -ne '')
	   {
		   if (Test-Path -Path botinfo -PathType Leaf)
		   {
			   Deploy-TGMethod get_me | Out-File -Path botinfo
		   }
		   $TextID = (Get-Content -Path botinfo | ConvertFrom-Json).result.username
		   $FileType = "text"
	   }

	   if ($StickerID -ne '')
	   {
		   $FileType = 'sticker'
	   }

	   if ($AminationID -ne '')
	   {
		   $FileType = 'animation'
	   }

	   if ($PhotoID -ne '')
	   {
		   $FileType = 'photo'
	   }

	   if ($VideoID -ne '')
	   {
		   $FileType = 'video'
	   }

	   if ($AudioID -ne '')
	   {
		   $FileType = 'audio'
	   }

	   if ($VoiceID -ne '')
	   {
		   $FileType = 'voice'
	   }

	   if ($DocumentID -ne '')
	   {
		   $FileType = 'document'
	   }
   }

   function Get-NormalReply {
	   Switch($FirstNormal)
	   {
		   $PF+'start' {
			   $TextID = "This is a PowerShell Bot, use /source to download."
			   $ReplyID = $MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $PF+'source' {
			   $TextID = "Download PowerShell Bot source from <https://github.com/adamantinum/PSTelegramBot>"
			   $ReplyID = $MessageID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }

		   $PF+'help' {
			   $TextID = Get-Content -Path README.md
			   $ReplyID = $MessageID
			   Deploy-TGMethod send_message | Out-File -path /dev/null
		   }
	   }
   }

   function Get-Inlinereply {
	   Switch($Result)
	   {
		   'ok' {
			   $Title = 'Ok'
			   $MessageText = 'Ok'
			   $Description 'Alright'
			   $ReturnQuery = Invoke-InLine article
			   Deploy-TGMethod send_inline | Out-File -Path /dev/null
		   }
	   }
   }

   function Get-ButtonReply {
	   Switch($CallbackMessageText)
	   {
		   test {
			   $TextID = $CallbackData
			   Deploy-TGMethod button_reply | Out-Filr -Path /dev/null
			   $ChatID = $CallbackUserID
			   Deploy-TGMethod send_message | Out-File -Path /dev/null
		   }
	   }
   }

   function Invoke-ProcessReply {
	   $Message = ($TGInput | ConvertTo-Json).message
	   $Inline = ($TGInput | ConvertTo-Json).inline_query
	   $Callback = ($TGInput | ConvertTo-Json).callback_query
	   $FileType = $Message.chat.type
	   if (!$Message.text -and ($FileType -ne "private") -and !$Inline -and !$Callback)
	   {
		   exit
	   }

	   # User database
	   $UsernameTag = $Message.from.username
	   $UsernameID = $Message.from.id
	   $UsernameFirstName = $Message.from.first_name
	   $UsernameLastName = $Messange.from.last_name
	   if (!$UsernameID)
	   {
		   Test-Path -Path db/users -PathType Container -and New-Item -Name db/users/ -ItemType Directory
		   $FileUser = "db/users/$UsernameTag"
		   if (Test-Path -Path $FileUser -PathType Leaf)
		   {
			   !$UsernameTag -and $UsernameTag = "(empty)"
			   @{
				   'tag' = $UsernameTag
				   'id' = $UsernameID
				   'fname' = $UsernameFirstName
				   'lname' = $UsernameLastName
			   } | ConvertTo-Json | Out-File -Path $FileUser
		   }
		   
		   if ("tag: $UsernameTag" -ne (Select-String -LiteralPath $FileUser -Pattern "tag" -Raw))
		   {
			   $FileUser = $FileUser -replace "tag: .*", "tag :$UsernameTag"
		   }

		   if ("fname: $UsernameFirstName" -ne (Select-String -LiternalPath $FileUser -Pattern "fname" -Raw)
		   {
			   $FileUser = $FileUser -replace "fname: .*", "fname: $UsernameFirstName"
		   }

		   if ("lname: $UsernameLastName" -ne (Select-String -LiternalPath $FileUser -Pattern "lname" -Raw)
		   {
			   $FileUser = $FileUser -replace "lname: .*", "lname: $UsernameLastName"
		   }
	   }

   Set-PSDebug -Off

} 1>>"log.log" 2>&1
