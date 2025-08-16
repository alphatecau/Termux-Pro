#!/data/data/com.termux/files/usr/bin/bash
termux-setup-storage -y >/dev/null 2>&1
mkdir -p /sdcard/termux-backups
while true; do
  ts=$(date +"%Y%m%d-%H%M%S")
  backup="/sdcard/termux-backups/termux-$ts.tar.zst"
  tar -I "zstd --password=$BACKUP_PASSPHRASE" -cf "$backup" -C /data/data/com.termux/files/home .
  mkdir -p /data/data/com.termux/files/home/restore-test
  if tar -I "zstd --password=$BACKUP_PASSPHRASE" -xf "$backup" -C /data/data/com.termux/files/home/restore-test --strip-components=1; then
    echo "✅ Backup verified: $backup"
  else
    echo "❌ Backup failed, removing $backup"
    rm -f "$backup"
  fi
  rm -rf /data/data/com.termux/files/home/restore-test/*
  # Keep only 7 latest backups
  ls -t /sdcard/termux-backups/termux-*.tar.zst 2>/dev/null | sed -e '1,7d' | xargs -r rm -f
  sleep 86400
done
