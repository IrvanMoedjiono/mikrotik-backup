# Use Alpine 3.20 as the base image
FROM alpine:3.20

# Set the maintainer
LABEL maintainer="yoga.november2000@gmail.com"

# Install necessary packages
RUN apk add --no-cache \
    openssh-client \
    tzdata \
    logrotate \
    bash \
    coreutils

# Set up a non-root user
RUN adduser -D backupuser
WORKDIR /home/backupuser

# Create .ssh directory with correct permissions
RUN mkdir -p /home/backupuser/.ssh && \
    chmod 700 /home/backupuser/.ssh && \
    chown backupuser:backupuser /home/backupuser/.ssh 

# Add logrotate configuration
COPY logrotate.conf /etc/logrotate.d/mikrotik-backup

# Copy the backup script
COPY mikrotik_backup.sh .
RUN chmod +x mikrotik_backup.sh

# Set environment variables (these can be overridden at runtime)
ENV MIKROTIK_ROUTER=10.1.1.127
ENV MIKROTIK_USER=admin
ENV MIKROTIK_BACKUP_ENCRYPT=PASSWORD
ENV MIKROTIK_SSH_PORT=22
ENV MIKROTIK_MAX_BACKUPS=3
ENV TZDATA=Asia/Jakarta
ENV CRON_SCHEDULE="0 0 * * *"

# Create log files and set permissions
RUN touch /var/log/cron.log /var/log/mikrotik_backup.log && \
    chmod 0644 /var/log/cron.log /var/log/mikrotik_backup.log && \
    chown backupuser:backupuser /var/log/cron.log /var/log/mikrotik_backup.log

# Create a startup script
RUN echo '#!/bin/bash\n\
echo "Starting container..."\n\
if [ -f /home/backupuser/.ssh/id_rsa ]; then\n\
  chmod 600 /home/backupuser/.ssh/id_rsa\n\
  chown backupuser:backupuser /home/backupuser/.ssh/id_rsa\n\
  echo "SSH key permissions set"\n\
fi\n\
if [ -n "$MIKROTIK_ROUTER" ]; then\n\
  ssh-keyscan -H $MIKROTIK_ROUTER >> /home/backupuser/.ssh/known_hosts\n\
  chown backupuser:backupuser /home/backupuser/.ssh/known_hosts\n\
  chmod 644 /home/backupuser/.ssh/known_hosts\n\
  echo "Added $MIKROTIK_ROUTER to known_hosts"\n\
fi\n\
# Set the timezone\n\
if [ -n "$TZDATA" ]; then\n\
  ln -snf /usr/share/zoneinfo/$TZDATA /etc/localtime && echo $TZDATA > /etc/timezone\n\
  echo "Timezone set to $TZDATA"\n\
fi\n\
echo "$CRON_SCHEDULE root . /etc/environment && /home/backupuser/mikrotik_backup.sh >> /var/log/mikrotik_backup.log 2>&1" > /etc/crontabs/root\n\
chmod 0644 /etc/crontabs/root\n\
env > /etc/environment\n\
echo "Cron job set up with schedule: $CRON_SCHEDULE"\n\
echo "Starting cron service..."\n\
crond -f -d 8' > /start.sh \
&& chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]