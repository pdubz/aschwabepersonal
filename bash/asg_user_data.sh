#!/bin/bash -x
log_msg () {
DATE="[$(date '+%Y-%m-%d %H:%M:%S')]"
if test "$1" == "i"; then
    MSG="\033[0;32m ${DATE} [INFO] ${2} \033[0m"
elif test "$1" == "e"; then
    MSG="\033[0;31m ${DATE} [ERROR] ${2} \033[0m"
elif test "$1" == "w"; then
    MSG="\033[1;33m ${DATE} [WARN] ${2} \033[0m"
else
    MSG="\033[0;32m ${DATE} [INFO] ${2} \033[0m"
fi
LOG_FOLDER="/var/log/ts"
if test -d "${LOG_FOLDER}"; then
    :
else
    echo "Log Folder (${LOG_FOLDER}) doesn't exist, creating..."
    mkdir ${LOG_FOLDER}
fi
LOG_FILE="${LOG_FOLDER}/asg_user_data.log"
if test -f "${LOG_FILE}"; then
    :
else
    echo "Log File (${LOG_FILE}) doesn't exist, creating..."
    touch "${LOG_FILE}"
fi
echo -e "${MSG}" | tee -a "${LOG_FILE}"
}
get_region () {
current_region=$(curl -sS http://169.254.169.254/latest/meta-data/placement/availability-zone/ | sed 's/.$//')
echo "${current_region}"
}
get_instance_id () {
instance=$(curl -sS http://169.254.169.254/latest/meta-data/instance-id)
echo "${instance}"
}
get_cf_stack_name () {
iid=$(get_instance_id)
reg=$(get_region)
stack_name=$(aws ec2 describe-instances --instance-ids "${iid}" --region "${reg}" | grep '"Key": "aws:cloudformation:stack-name"' -C 1 | grep "Value" | cut -d '"' -f 4)
echo "${stack_name}"
}
get_cf_stack_resource () {
iid=$(get_instance_id)
reg=$(get_region)
stack_resource=$(aws ec2 describe-instances --instance-ids "${iid}" --region "${reg}" | grep '"Key": "aws:cloudformation:logical-id"' -C 1 | grep "Value" | cut -d '"' -f 4)
echo "${stack_resource}"
}
signal_stack () {
log_msg "i" "Beginning to signal success=${1} to the CloudFormation stack."
INSTANCE_ID=$(get_instance_id)
log_msg "i" "Instance ID: ${INSTANCE_ID}"
CF_STACK=$(get_cf_stack_name)
log_msg "i" "CloudFormation Stack Name: ${CF_STACK}"
CF_RESOURCE=$(get_cf_stack_resource)
log_msg "i" "CloudFormation Resource: ${CF_RESOURCE}"
REGION=$(get_region)
log_msg "i" "Current AWS Region: ${REGION}"
if /opt/aws/bin/cfn-signal --success="${1}" --stack "${CF_STACK}" --resource "${CF_RESOURCE}" --region "${REGION}"; then
    log_msg "i" "Successfully signaled success=${1} to the CloudFormation stack."
else
    log_msg "e" "Signaling success=${1} to CloudFormation failed with exit code ${?}."
fi
}
log_msg "i" "Starting CloudFormation User Data."
PACKAGES=(
# Needed to signal success to the ASG
aws-cli
aws-cfn-bootstrap
# Packages installed for agent installs
bind-utils
python
python-pip
curl
ruby
jq
# Packages TS will use
python3
python3-pip
parted
# Installed for sysadmin needs.
bash-completion
yum-utils
tmux
vim
# Install for use here in user data
wget
)
ERROR_COUNT=0
for i in "${PACKAGES[@]}"
do
j=0
PACKAGE_INSTALLED="false"
until test "${PACKAGE_INSTALLED}" == "true" || ( (( j > 5 )) ); do
    if yum -y install "${i}"; then
    log_msg "i" "Successfully installed ${i} using yum."
    PACKAGE_INSTALLED="true"
    else
    log_msg "w" "Yum install of ${i} returned exit code of ${?}. Retrying install. This is retry ${j}."
    fi
    (( j++ ))
done
if (( j > 5 )); then
    (( ERROR_COUNT++ ))
    log_msg "e" "Yum install of ${i} never exited with 0 after 5 attempts. Incrementing error count to ${ERROR_COUNT}."
fi
done
if (( ERROR_COUNT > 0 )); then
log_msg "e" "Failed to install necessary packages via yum with ${ERROR_COUNT} errors. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until amazon-linux-extras list | grep "epel.*enabled" || ( (( i > 5 )) ); do
if amazon-linux-extras install -y epel; then
    log_msg "i" "Successfully installed EPEL."
else
    log_msg "w" "Installing EPEL via amazon-linux-extras returned exit code of ${?}. Trying to install again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to install EPEL using amazon-linux-extras after 5 attempts. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
if yum -y update; then
log_msg "i" "Successfully executed a yum update."
else
log_msg "e" "Yum update exited with ${?}. Exiting and marking stack as failed."
signal_stack "false" && exit
fi
i=0
until ls /tmp/install || ( (( i > 5)) ); do
REGION=$(get_region)
if aws s3 cp s3://aws-codedeploy-"${REGION}"/latest/install /tmp/install --region "${REGION}"; then
    log_msg "i" "Successfully downloaded CodeDeploy install script from S3 to /tmp/install."
else
    log_msg "w" "Downloading CodeDeploy install script from S3 to /tmp/install exited with ${?}. Trying to download again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to download CodeDeploy install script from S3 to /tmp/install after 5 attempts. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until ( ls -al /tmp/install | awk '{print $1}' | grep ".*x.*x.*x$" ) || ( ((i > 5)) ); do
if chmod +x /tmp/install; then
    log_msg "i" "Successfully set CodeDeploy install script (/tmp/install) to be executable."
else
    log_msg "w" "Setting CodeDeploy install script (/tmp/install) to be executable failed with ${?}. Trying to modify permissions again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to set CodeDeploy install script (/tmp/install) to be executable after 5 attempts. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
PACKAGE_INSTALLED="false"
until test "${PACKAGE_INSTALLED}" == "true" || ( ((i > 5)) ); do
cd /tmp || exit
if ./install rpm; then
    log_msg "i" "Successfully installed CodeDeploy using downloaded script (/tmp/install)."
    PACKAGE_INSTALLED="true"
else
    log_msg "w" "Installing CodeDeploy using downloaded script (/tmp/install) failed with ${?}. Trying to install again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to install CodeDeploy using downloaded script (/tmp/install) after 5 attempts. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until ( file -s /dev/nvme1n1 | grep "x86 boot sector" ) || ( (( i > 5 )) ); do
if parted -sa opt /dev/nvme1n1 mklabel gpt; then
    log_msg "i" "Successfully created gpt partition on /dev/nvme1n1."
else
    log_msg "w" "Creating gpt partition on /dev/nvme1n1 failed with exit code ${?}. Trying to create partition again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to create gpt partition on /dev/nvme1n1 after 5 attemps. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi

i=0
until ( file -s /dev/nvme1n1 | grep ext4 ) || ( (( i > 5 )) ); do
if mkfs -t ext4 /dev/nvme1n1; then
    log_msg "i" "Successfully created ext4 filesystem on /dev/nvme1n1."
else
    log_msg "w" "Creating ext4 filesystem on /dev/nvme1n1 failed with exit code ${?}. Trying to create filesystem again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to create ext4 filesystem on /dev/nvme1n1 after 5 attemps. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until test -d /etc/ecs/ || ( (( i > 5 )) ); do
if mkdir /etc/ecs; then
    log_msg "i" "Successfully created the /etc/ecs/ directory."
else
    log_msg "w" "Creating the /etc/ecs/ directory failed with exit code ${?}. Trying to create directory again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to create the /etc/ecs/ directory after 5 attemps. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until test -f /etc/ecs/ecs.config || ( (( i > 5 )) ); do
if touch /etc/ecs/ecs.config; then
    log_msg "i" "Successfully created the /etc/ecs/ecs.config file."
else
    log_msg "w" "Creating the /etc/ecs/ecs.config file failed with exit code ${?}. Trying to create file again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "e" "Failed to create the /etc/ecs/ecs.config file after 5 attemps. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
ECS_CLUSTER=$(get_cf_stack_name)
CONFIGS=(
"ECS_CLUSTER=${ECS_CLUSTER}"
"ECS_ENABLE_TASK_IAM_ROLE=true"
"ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true"
"ECS_ENABLE_CONTAINER_METADATA=true"
#"ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance" # Disabling 'ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM' as it currently throws 'Error registering: InvalidParameterException: Long arn format must be enabled for tagging.'
"ECS_RESERVED_MEMORY=1024"
"ECS_CONTAINER_STOP_TIMEOUT=120s"
"ECS_ENABLE_CONTAINER_METADATA=true"
)
ERROR_COUNT=0
for i in "${CONFIGS[@]}"; do
j=0
until grep "${i}" /etc/ecs/ecs.config || ( (( j > 5 )) ); do
    if echo "${i}" >> /etc/ecs/ecs.config; then
    log_msg "i" "Successfully appended '${i}' to /etc/ecs/ecs.config."
    else
    log_msg "w" "Appending '${i}' to /etc/ecs/ecs.config failed with exit code ${?}. Trying to add line again. This is retry ${j}."
    fi
    (( j++ ))
done
if (( j > 5 )); then
    (( ERROR_COUNT++ ))
    log_msg "e" "Appending '${i}' to /etc/ecs/ecs.config failed after 5 attempts. Incrementing error count to ${ERROR_COUNT}."
fi
done
if (( ERROR_COUNT > 0 )); then
log_msg "e" "Failed to append necessary configs to /etc/ecs/ecs.config with ${ERROR_COUNT} errors. Exiting and marking CloudFormation stack as failed."
signal_stack "false" && exit
fi
i=0
until ( ls /etc/bash_completion.d/docker.sh ) || ( ((i > 5)) ); do
if curl -sS https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh; then
    log_msg "i" "Successfully downloaded docker autocomplete script from GitHub to /etc/bash_completion.d/docker.sh."
else
    log_msg "w" "Downloading docker autocomplete script from GitHub to /etc/bash_completion.d/docker.sh exited with ${?}. Trying to download again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "w" "Failed to download the docker autocomplete file to /etc/bash_completion.d/docker.sh after 5 attemps. User Data will proceed."
fi
i=0
until ( ls -al /etc/bash_completion.d/docker.sh | awk '{print $1}' | grep ".*x.*x.*x$" ) || ( ((i > 5)) ); do
if chmod +x /etc/bash_completion.d/docker.sh; then
    log_msg "i" "Successfully set docker autocomplete script (/etc/bash_completion.d/docker.sh) to be executable."
else
    log_msg "w" "Setting docker autocomplete script (/etc/bash_completion.d/docker.sh) to be executable failed with ${?}. Trying to modify permissions again. This is retry ${i}."
fi
(( i++ ))
done
if (( i > 5 )); then
log_msg "w" "Failed to set docker autocomplete script (/etc/bash_completion.d/docker.sh) to be executable after 5 attempts. User Data will proceed."
fi
if ls /etc/bash_completion.d/aws_bash_completer; then
i=0
until ( ls -al /etc/bash_completion.d/aws_bash_completer | awk '{print $1}' | grep ".*x.*x.*x$" ) || ( ((i > 5)) ); do
    if chmod +x /etc/bash_completion.d/aws_bash_completer; then
    log_msg "i" "Successfully set AWS autocomplete script (/etc/bash_completion.d/aws_bash_completer) to be executable."
    else
        log_msg "w" "Setting AWS autocomplete script (/etc/bash_completion.d/aws_bash_completer) to be executable failed with ${?}. Trying to modify permissions again. This is retry ${i}."
    fi
    (( i++ ))
done
if (( i > 5 )); then
    log_msg "w" "Failed to set AWS autocomplete script (/etc/bash_completion.d/aws_bash_completer) to be executable after 5 attempts. User Data will proceed."
fi
else
log_msg "w" "AWS Bash Completer doesn't exist (/etc/bash_completion.d/aws_bash_completer), moving on."
fi
log_msg "i" "Adding config to /home/ec2-user/.bashrc and /root/.bashrc."
mkdir -p /opt/ts/
touch /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.1.1 Ensure SELinux is not disabled in bootloader configuration (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.1.2 Ensure the SELinux state is enforcing (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.1.3 Ensure SELinux policy is configured (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.1.4 Ensure SETroubleshoot is not installed (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.1.5 Ensure the MCS Translation Service (mcstrans) is not installed (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "1.6.2 Ensure SELinux is installed (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "3.1.1 Ensure IP forwarding is disabled (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
printf '%s\n' "5.2.16 Ensure SSH Idle Timeout Interval is configured (Scored)" >> /opt/ts/ts-fi-linux-amazon-linux-2-hardening.config
touch /usr/bin/sqlcmd
chmod +x /usr/bin/sqlcmd
printf '%s\n' '#!/bin/bash -x' >> /usr/bin/sqlcmd
printf '%s\n' "docker run -it --rm --volume \${PWD}:\${PWD} --workdir \${PWD} --entrypoint '/opt/mssql-tools/bin/sqlcmd' 'mcr.microsoft.com/mssql-tools' \"\$@\"" >> /usr/bin/sqlcmd
touch /usr/bin/cqlsh
chmod +x /usr/bin/cqlsh
printf '%s\n' '#!/bin/bash -x' >> /usr/bin/cqlsh
printf '%s\n' "docker run -it --rm --volume \${PWD}:\${PWD} --workdir \${PWD} --entrypoint /usr/bin/cqlsh cassandra \"\$@\"" >> /usr/bin/cqlsh
printf '\n%s\n' "alias tsbash=\"docker exec -it \$(docker ps | grep 'arch[1-2]' | awk '{print \$1}') /bin/bash\"" >> /home/ec2-user/.bashrc
printf '\n%s\n' "alias tsbash=\"docker exec -it \$(docker ps | grep 'arch[1-2]' | awk '{print \$1}') /bin/bash\"" >> /root/.bashrc
printf '\n%s\n' "alias ll=\"ls -alh\"" >> /home/ec2-user/.bashrc
printf '\n%s\n' "alias ll=\"ls -alh\"" >> /root/.bashrc
printf '\n%s\n' "export PS1=\"\[\033[38;5;3m\]\u@\H:[\w]\n\\$ \[\$(tput sgr0)\]\"" >> /home/ec2-user/.bashrc
printf '\n%s\n' "export PS1=\"\[\033[38;5;3m\]\u@\H:[\w]\n\\$ \[\$(tput sgr0)\]\"" >> /root/.bashrc
log_msg "i" "Completed adding config to /home/ec2-user/.bashrc and /root/.bashrc."
log_msg "i" "CloudFormation UserData complete. Attempting to signal success to the CloudFormation stack."
if signal_stack "true"; then
log_msg "i" "Signaling success to the CloudFormation stack was successful. UserData complete."
else
log_msg "i" "Signaling success to the CloudFormation stack failed with exit code ${?}. This stack will probably just timeout."
fi
