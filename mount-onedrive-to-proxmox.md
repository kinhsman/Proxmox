# Mounting OneDrive Storage to Proxmox Host

This guide provides step-by-step instructions on how to mount your OneDrive storage to a Proxmox host using `rclone` and `fuse3`.

## Prerequisites

* A running Proxmox host.
* Internet connectivity.
* A Microsoft OneDrive account.

## Installation and Configuration

1.  **Create a Mount Point:**

    ```bash
    mkdir /mnt/onedrive
    ```

2.  **Install `fuse3`:**

    ```bash
    sudo apt install fuse3 -y
    ```

3.  **Install `rclone`:**

    ```bash
    sudo -v ; curl https://rclone.org/install.sh | sudo bash
    ```

4.  **Configure `rclone` for OneDrive:**

    ```bash
    rclone config
    ```

    * Follow the prompts to configure `rclone` for your OneDrive account. You'll need to authorize `rclone` to access your OneDrive.
    * When prompted for a name for your remote, use `onedrive`.
    * You will need to install rclone in your PC/mac and then run: `rclone authorize "onedrive"` and login with your OneDrive account to get the token.

5.  **(Optional) Test Mounting OneDrive:**

    ```bash
    /usr/bin/rclone mount onedrive: /mnt/onedrive --allow-other --cache-db-purge --allow-non-empty
    ```

    * `--allow-other` allows other users on the system to access the mounted directory.
    * `--cache-db-purge` removes old cache entries.
    * `--allow-non-empty` allows mounting to an existing non-empty directory.

6.  **Create a Systemd Service for Auto-Mounting:**

    * Create a new service file:

        ```bash
        nano /etc/systemd/system/rclone-onedrive.service
        ```

    * Add the following content to the file:

        ```
        [Unit]
        Description=Rclone Mount OneDrive
        After=network-online.target

        [Service]
        Type=simple
        ExecStart=/usr/bin/rclone mount onedrive: /mnt/onedrive --allow-other --cache-db-purge --allow-non-empty
        ExecStop=/bin/fusermount -u /mnt/onedrive
        Restart=on-failure
        User=root
        Group=root
        Environment=RCLONE_CONFIG=/root/.config/rclone/rclone.conf

        [Install]
        WantedBy=multi-user.target
        ```

    * Save and close the file.

7.  **Enable and Start the Service:**

    ```bash
    systemctl enable rclone-onedrive
    systemctl start rclone-onedrive
    ```

8.  **Verify the Service Status:**

    ```bash
    systemctl status rclone-onedrive
    ```

    * Ensure the service is running without errors.

## Testing and Cleanup (Optional)

1.  **Test Write Speed with a Test File:**

    ```bash
    dd if=/dev/zero of=/mnt/onedrive/testfile bs=4M count=64 conv=fdatasync
    ```

2.  **Test Read Speed:**

    ```bash
    sync; echo 3 > /proc/sys/vm/drop_caches
    dd if=/mnt/onedrive/testfile of=/dev/null bs=4M
    ```

3.  **Remove the Test File:**

    ```bash
    rm /mnt/onedrive/testfile
    ```

## Notes

* Adjust the `rclone mount` options as needed for your specific use case.
* Ensure your `rclone` configuration is secure, especially if you're storing sensitive data.
* This setup uses root user. For better security, creating a dedicated user for rclone is recommended.
