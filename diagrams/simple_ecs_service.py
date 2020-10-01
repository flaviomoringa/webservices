from diagrams import Cluster, Diagram
from diagrams.aws.network import VPC, PublicSubnet, PrivateSubnet, Endpoint, ELB, Route53
from diagrams.aws.compute import ECS, ECR, EC2, AutoScaling
from diagrams.aws.management import Cloudwatch

with Diagram("Simple ECS Service", show=True):
    with Cluster("AWS Account"):
        with Cluster("Hosted Zone\nflavio.com"):
            maindomain = Route53("webservices.*.flavio.com")
            secondarydomain = Route53("ws.*.flavio.com")

        with Cluster("ECR"):

            ecr = ECR("Webservices Image")

        with Cluster("VPC"):

            PrivateSubnet("Private Subnet")
            with Cluster("Loadbalancing"):

                loadbalancer = ELB("Loadbalancer\nEndpoint")

                [maindomain, secondarydomain] >> loadbalancer 

            with Cluster("ECS Cluster"):

                clusterecs = ECS("Webservices-Prod")

                autoscalingclusterecs = AutoScaling("Cluster Scaling")

                ec2 = EC2("EC2 Instances")

                alarmscluster = Cloudwatch("Cluster Reserved CPU Alarm")

                clusterecs >> alarmscluster >> autoscalingclusterecs >> ec2

                with Cluster("Webservices Service"):

                    webservices = EC2("Webservices Tasks")

                    autoscalingwebservices = AutoScaling("Webservices docker scaling")

                    alarmswebservices = Cloudwatch("Service CPU Alarm")

                    loadbalancer >> webservices >> ecr
                    webservices >> alarmswebservices >> autoscalingwebservices
