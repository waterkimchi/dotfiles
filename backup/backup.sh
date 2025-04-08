#!/bin/bash

# --- Configuration ---
STORAGE_DEVICE="/Volumes/Storage"
LOCAL_DOCUMENTS="$HOME/Documents"
BACKUP_DOCUMENTS="$STORAGE_DEVICE/Documents"
BACKUP_BACKUP_DOCUMENTS="$STORAGE_DEVICE/Documents_Backup"
DOTFILES_DIR="$STORAGE_DEVICE/config/dotfiles"
PASSWORDS_FILE="$STORAGE_DEVICE/config/Passwords.csv"

# --- Functions ---

confirm() {
	read -r -p "$1 (y/N): " response
	case "$response" in
	[yY][eE][sS] | [yY])
		return 0
		;;
	*)
		return 1
		;;
	esac
}

update_dotfiles() {
	echo "--- Updating Dotfiles ---"
	if [ -d "$DOTFILES_DIR" ]; then
		cd "$DOTFILES_DIR"
		if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
			echo "Pulling latest changes from Git..."
			git pull origin "$(git default-branch)" || {
				echo "Error pulling changes from Git."
				return 1
			}
			echo "Dotfiles updated successfully."
		else
			echo "Warning: '$DOTFILES_DIR' is not a Git repository."
			echo "Ensure it's a cloned repository for automatic updates."
		fi
		cd - >/dev/null # Go back to the previous directory
	else
		echo "Error: Dotfiles directory '$DOTFILES_DIR' not found."
		return 1
	fi
	return 0
}

update_passwords() {
	echo "--- Updating Passwords ---"

	echo "Please manually export your latest passwords from Keychain Access"
	echo "and replace the '$PASSWORDS_FILE' on your external backup."
	echo "Once done, you can close Keychain Access and proceed."
	read -n 1 -r -p "Press Enter to continue..."
	echo "Opening Keychain Access..."
	open -a "Keychain Access"

	if [ -f "$PASSWORDS_FILE" ]; then
		echo "Showing information for '$PASSWORDS_FILE':"
		stat "$PASSWORDS_FILE" | grep "Modify"
	else
		echo "Warning: Password file '$PASSWORDS_FILE' not found."
	fi
	echo "" # Add a newline after the user input
	echo "Password update process noted."
	return 0
}

sync_documents() {
	echo "--- Syncing Documents Folder ---"
	echo "Making backup of current folder..."

	if [ ! -d "$LOCAL_DOCUMENTS" ]; then
		echo "Error: Local Documents folder '$LOCAL_DOCUMENTS' not found."
		return 1
	fi

	echo "Copying/syncing '$BACKUP_DOCUMENTS' to '$BACKUP_BACKUP_DOCUMENTS'..."
	rsync -ar --progress --stats "$BACKUP_DOCUMENTS/" "$BACKUP_BACKUP_DOCUMENTS/"

	echo "Copying/syncing '$LOCAL_DOCUMENTS' to '$BACKUP_DOCUMENTS'..."
	rsync -ar --progress --stats "$LOCAL_DOCUMENTS/" "$BACKUP_DOCUMENTS/"

	if [ $? -eq 0 ]; then
		echo "Documents folder synced successfully to '$BACKUP_DOCUMENTS'."
	else
		echo "Error occurred during the Documents folder sync."
		return 1
	fi
	return 0
}

# --- Main Script ---

echo "Starting backup update process..."
echo "Searching for backup device..."

if test -d "$STORAGE_DEVICE"; then
	echo "Backup device connected."
else
	echo "Backup device not found, terminating..."
	exit 1
fi

if confirm "Do you want to update dotfiles?"; then
	update_dotfiles
else
	echo "Skipping dotfiles update."
fi

if confirm "Do you want to sync your Documents folder?"; then
	sync_documents
else
	echo "Skipping Documents folder sync."
fi

if confirm "Do you want to update passwords (requires manual Keychain Access export)?"; then
	update_passwords
fi

echo "Backup update process complete."

exit 0
