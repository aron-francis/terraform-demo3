import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    action = event.get('action', '').lower()

    # Get all instances
    response = ec2.describe_instances()
    all_instances = [instance['InstanceId'] for reservation in response['Reservations'] for instance in reservation['Instances']]

    if action == 'start':
        # Filter stopped instances
        instances_to_start = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['stopped']}])
        instances_to_start = [instance['InstanceId'] for reservation in instances_to_start['Reservations'] for instance in reservation['Instances']]
        
        if instances_to_start:
            ec2.start_instances(InstanceIds=instances_to_start)
            print(f"Started EC2 instances: {instances_to_start}")
        else:
            print("No stopped instances to start")
    elif action == 'stop':
        # Filter running instances
        instances_to_stop = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
        instances_to_stop = [instance['InstanceId'] for reservation in instances_to_stop['Reservations'] for instance in reservation['Instances']]
        
        if instances_to_stop:
            ec2.stop_instances(InstanceIds=instances_to_stop)
            print(f"Stopped EC2 instances: {instances_to_stop}")
        else:
            print("No running instances to stop")
    else:
        print(f"Invalid action: {action}")

    return {
        'statusCode': 200,
        'body': f"Action '{action}' completed"
    }
