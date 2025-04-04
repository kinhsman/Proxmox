# Proxmox Alerts to Discord Integration

This project forwards Proxmox alerts from Gmail to a Discord channel using Google Apps Script and Gmail's SMTP server. 
The primary reason for this implementation is to handle Discord's 2000-character limit, truncating messages appropriately to ensure compatibility.

## Setup Instructions

### Prerequisites
- A Gmail account
- A Discord server where you have permission to create webhooks
- A Proxmox server

### Step 1: Create Discord Webhook
1. In your Discord server, go to Server Settings → Integrations → Webhooks
2. Create a new webhook and copy its URL
3. Choose the channel where alerts should be posted

### Step 2: Set Up Google Apps Script
1. Navigate to [Google Apps Script](https://script.google.com/)
2. Click "New Project"
3. Replace the default code with:

```javascript
function forwardProxmoxAlertsToDiscord() {
  var discordWebhookUrl = "YOUR_DISCORD_WEBHOOK_URL_HERE";
  var emailAddress = "YOUR_GMAIL_USERNAME+proxmoxalerts@gmail.com";
  var maxMessageLength = 1900;
  
  var threads = GmailApp.search("to:" + emailAddress + " is:unread");
  
  for (var i = 0; i < threads.length; i++) {
    var messages = threads[i].getMessages();
    
    for (var j = 0; j < messages.length; j++) {
      var message = messages[j];
      if (message.isUnread()) {
        var subject = message.getSubject();
        var body = message.getPlainBody();
        
        var truncatedBody = body.length > maxMessageLength ? 
          body.substring(0, maxMessageLength - 50) + "... [truncated]" : 
          body;
          
        var payload = {
          "content": "**New Proxmox Alert**\n**Subject:** " + subject + "\n**Message:** " + truncatedBody
        };
        
        var options = {
          "method": "post",
          "contentType": "application/json",
          "payload": JSON.stringify(payload)
        };
        
        UrlFetchApp.fetch(discordWebhookUrl, options);
        message.markRead();
      }
    }
    // Move the entire thread to Trash after processing
    threads[i].moveToTrash();
  }
}
```
4. Update these variables:
   - Replace `YOUR_DISCORD_WEBHOOK_URL_HERE` with your Discord webhook URL
   - Replace `YOUR_GMAIL_USERNAME` with your Gmail username

5. Set up a trigger:
   - Click the clock icon (Triggers) in the left sidebar
   - Click "+ Add Trigger"
   - Configure:
     - Function: `forwardProxmoxAlertsToDiscord`
     - Deployment: Head
     - Event source: Time-driven
     - Type: Minutes timer
     - Interval: Every 1 minute (or adjust as needed)
  - Save the trigger

6. Authorize the script:
   - Click "Run" and grant necessary permissions when prompted
   - Accept the Google authorization prompts

### Step 3: Create Gmail App Password
1. Go to [Google Account App Passwords](https://myaccount.google.com/apppasswords)
2. Generate a new app password
3. Save this 16-character password securely - you'll need it in `Step 4`

### Step 4: Configure Proxmox SMTP
In your Proxmox web interface:
1. Go to `Datacenter` → `Notifications`
2. Add a new SMTP server with these settings:
   - Server: `smtp.gmail.com`
   - Encryption: `STARTTLS`
   - Username: `YOUR_GMAIL_USERNAME@gmail.com`
   - Password: Your app password from Step 1
   - Additional Recipients: `YOUR_GMAIL_USERNAME+proxmoxalerts@gmail.com`
3. Leave other settings as default
4. Save the configuration

### (Optional) Step: Silence Gmail Push Notifications
To prevent duplicate notifications on your Gmail mobile app:
1. Go to Settings → Filters and Blocked Addresses
2. Create new filter with `to:YOUR_GMAIL_USERNAME+proxmoxalerts@gmail.com`
3. Apply action: Skip Inbox and Apply label "proxmoxalerts"

### Step 5: Test the Setup
1. In Proxmox, trigger a test notification
2. Check your Discord channel for the alert
3. Verify the email is marked as read in Gmail

## Troubleshooting
- Ensure all credentials are correct
- Check Google Apps Script execution logs
- Verify Discord webhook URL is valid
- Confirm Proxmox can reach smtp.gmail.com

## Notes
- Messages longer than 1900 characters will be truncated
- The script checks for new emails every minute (configurable)
- Gmail's app password is required due to 2FA/security settings




