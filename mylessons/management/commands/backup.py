from django.core.management.base import BaseCommand
from datetime import datetime
import subprocess
import os

class Command(BaseCommand):
    help = "Backup"

    def handle(self, *args, **kwargs):

        self.stdout.write("Starting database backup...")

        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        backup_filename = f"backup_{timestamp}.sql"

        backup_dir = '/home/mylessons/mylessons/Backups'
        backup_path = os.path.join(backup_dir, backup_filename)

        # Ensure the backup directory exists
        os.makedirs(backup_dir, exist_ok=True)

        # Using the MySQL options file for credentials
        command = "mysqldump -u mylessons -h mylessons.mysql.pythonanywhere-services.com --set-gtid-purged=OFF --no-tablespaces --column-statistics=0 'mylessons$default'  > db-backup.sql"

        # Execute the command
        try:
            subprocess.run(command, shell=True, check=True)
            self.stdout.write(f"Database backed up to {backup_path}")
        except subprocess.CalledProcessError as e:
            self.stdout.write(f"An error occurred: {str(e)}")
