import boto3
import os

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    instance_ids = os.environ['EC2_INSTANCE_IDS'].split(',')
    action = event.get('action', '').lower()

    # Get current state of instances
    response = ec2.describe_instances(InstanceIds=instance_ids)
    instance_states = {instance['InstanceId']: instance['State']['Name'] 
                       for reservation in response['Reservations'] 
                       for instance in reservation['Instances']}

    if action == 'start':
        instances_to_start = [id for id, state in instance_states.items() if state == 'stopped']
        if instances_to_start:
            ec2.start_instances(InstanceIds=instances_to_start)
            print(f"Started EC2 instances: {instances_to_start}")
        else:
            print("No stopped instances to start")
    elif action == 'stop':
        instances_to_stop = [id for id, state in instance_states.items() if state == 'running']
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
