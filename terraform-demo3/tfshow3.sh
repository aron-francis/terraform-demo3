#!/bin/bash

# Function to print a header
print_header() {
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}


# EC2 Instance
print_header "EC2 Instance(s)"
instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime,Tags[?Key==`Name`].Value|[0]]' --output json)

echo "InstanceId        InstanceType  State    StartTime           Name            StopTime"
echo "---------------   ------------  -------  -------------------  --------------  -------------------"

echo "$instances" | jq -r '.[][] | @tsv' | while IFS=$'\t' read -r id type state start name; do
    if [ "$state" == "stopped" ]; then
        stop_time=$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[*].Instances[*].StateTransitionReason' --output text | sed -n 's/.*(\(.*\) GMT).*/\1 GMT/p')
        start="-"
        [ -z "$stop_time" ] && stop_time="-"
    else
        stop_time="-"
    fi
    printf "%-16s %-13s %-8s %-19s %-15s %s\n" "$id" "$type" "$state" "${start:0:19}" "${name:-"-"}" "$stop_time"
done

sleep 2

# Updated section: EC2 Instance Start/Stop Times
: <<'END_COMMENT'
# Updated section: EC2 Instance Start/Stop Times
print_header "EC2 Instance Start/Stop Times"
instances=$(aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime,Tags[?Key==`Name`].Value|[0]]' --output json)

echo "InstanceId,State,Name,StartTime,StopTime"
echo "----------------------------------------"

echo "$instances" | jq -r '.[][] | @csv' | while IFS=',' read -r id state launch_time name; do
    id=$(echo "$id" | tr -d '"')
    state=$(echo "$state" | tr -d '"')
    name=$(echo "$name" | tr -d '"')
    launch_time=$(echo "$launch_time" | tr -d '"')
    
    if [ "$state" == "running" ]; then
        echo "$id,$state,$name,$launch_time,-"
    else
        stop_time=$(aws ec2 describe-instance-status --instance-ids "$id" --include-all-instances --query 'InstanceStatuses[0].Events[?Code==`instance-stop`].NotBefore' --output table 2>/dev/null)
        if [ -z "$stop_time" ]; then
            stop_time="-"
        fi
        echo "$id,$state,$name,-,$stop_time"
    fi
done | column -t -s ','


sleep 2

# Lambda Functions
print_header "Lambda Function(s)"
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime,Handler]' --output table

sleep 2

END_COMMENT