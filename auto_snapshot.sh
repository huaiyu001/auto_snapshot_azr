#!/bin/bash
### Create snapshot ###
#Set configure file
config_file=/etc/auto_snapshot.conf
log_file=/var/log/auto_snapshot.log
output_file=/tmp/auto_snapshot_output.txt 
if [ ! -f "$config_file" ]; then
	cat >"$config_file" <<END
##############################################################
## Please put the information follow the following format ####
## All the disks of the instance will be backed up regularly##
##############################################################
Subscription_name:Backup_RG_NAME:Instance_name
END
fi

if [ ! -f "$log_file" ]; then
	touch "$log_file"
fi

if [ ! -f "$output_file" ]; then
        touch "$output_file"
fi


cat "$config_file" | awk 'NR>=6 {print}' > /tmp/auto_snapshot_vmslist_temp.txt
while read rows_vm; do
	sub_name=$(echo "$rows_vm" | cut -d ':' -f 1)
	rg_name=$(echo "$rows_vm" | cut -d ':' -f 2)
	instance_name=$(echo "$rows_vm" | cut -d ':' -f 3)

	az account set -s "$sub_name"
	az disk list -g "$rg_name" --output table | grep -i "$instance_name" | cut -d ' ' -f 1 > /tmp/singlevm_disks_temp.txt
		while read rows_disk; do
			az snapshot create -g "$rg_name" -n ""$rows_disk"_"$(date +%Y%m%d%H%M%S)"" --source "$rows_disk" | jq '.id' | xargs -i echo ""$(date +%Y-%m-%d-%H:%M:%S)" >>> add:{}" >> "$log_file"
			if [ $? == 0 ];then
				echo "$rows_disk backup is successful" >> $output_file
			else
				echo "$rows_disk backup failed" >> $output_file
			fi
		done < /tmp/singlevm_disks_temp.txt
		rm -f /tmp/singlevm_disks_temp.txt
done < /tmp/auto_snapshot_vmslist_temp.txt
rm -f /tmp/auto_snapshot_vmslist_temp.txt


### Delete snapshot ###
touch /tmp/all_snapshots_temp.txt
cat "$config_file" | awk 'NR>=6 {print}' > /tmp/auto_snapshot_vmslist_temp.txt
while read rows_list_vmdisk; do
	sub_name=$(echo "$rows_list_vmdisk" | cut -d ':' -f 1)
	rg_name=$(echo "$rows_list_vmdisk" | cut -d ':' -f 2)
	az account set -s "$sub_name"
	az snapshot list -g "$rg_name" | jq '.[].id' >> /tmp/all_snapshots_temp.txt 
done < /tmp/auto_snapshot_vmslist_temp.txt
rm -f /tmp/auto_snapshot_vmslist_temp.txt
cat /tmp/all_snapshots_temp.txt | grep $(date -d "8 days ago" +%Y%m%d) > /tmp/all_del_snapshots_temp.txt
while read rows_del; do
	del_disk=$(echo "$rows_del" | sed 's/"//g')
	az snapshot delete --ids $del_disk
	if [ $? == 0 ]; then
		echo ""$(date +%Y-%m-%d-%H:%M:%S)" >>> del:"$del_disk" successful" >> "$log_file"
	else
		echo ""$(date +%Y-%m-%d-%H:%M:%S)" >>> del:"$del_disk" fault" >> "$log_file"
	fi
done < /tmp/all_del_snapshots_temp.txt
rm -f /tmp/all_snapshots_temp.txt
rm -f /tmp/all_del_snapshots_temp.txt
exit
