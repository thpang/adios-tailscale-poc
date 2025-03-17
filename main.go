package main

import (
	"fmt"
	"os"

	awsec2 "github.com/pulumi/pulumi-aws/sdk/v6/go/aws/ec2"
	awsxec2 "github.com/pulumi/pulumi-awsx/sdk/v2/go/awsx/ec2"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// Variables
var prefix = "adios-tailscale-poc" // os.Getenv("PREFIX")
var vpc_count = 2                  // os.Getenv("VPC_COUNT")
var vpc_az_count = 2               // os.Getenv("VPC_AZ_COUNT")
var vpc_cidr_mask = 24             // os.Getenv("VPC_CIDR_MASK")
var vpc_subnet_cidr_mask = 28      // os.Getenv("VPC_SUBNET_CIDR_MASK")
var ec2_keypair_name = prefix      // os.Getenv("EC2_KEYPAIR_NAME")
var ec2_vpc_count = 2              // os.Getenv("EC2_VPC_COUNT")
var sg_vpn_cidr = os.Getenv("SG_VPN_CIDR")

// os.Getenv("AWS_REGION")
// TODO: Look at Viper for configuration management - https://github.com/spf13/viper

var vpc_ids pulumi.StringArray
var sg_ids pulumi.StringArray
var vm_host_names pulumi.StringArray

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {

		// Create keypair for use with the ec2 instances created
		keyPair, err := awsec2.LookupKeyPair(ctx, &awsec2.LookupKeyPairArgs{
			KeyName:          &ec2_keypair_name,
			IncludePublicKey: pulumi.BoolRef(true),
		})
		if err != nil {
			return err
		}
		// spew.Dump(keyPair)

		// Find AMI for ubuntu image desired
		ubuntu, err := awsec2.LookupAmi(ctx, &awsec2.LookupAmiArgs{
			MostRecent: pulumi.BoolRef(true),
			Filters: []awsec2.GetAmiFilter{
				{
					Name: "name",
					Values: []string{
						"ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*",
					},
				},
				{
					Name: "virtualization-type",
					Values: []string{
						"hvm",
					},
				},
			},
			Owners: []string{
				"099720109477",
			},
		}, nil)
		if err != nil {
			return err
		}

		// Create vpc_count number of VPCs
		for count := range vpc_count {
			var vpc_name = fmt.Sprintf("%s-vpc-%02d", prefix, count)
			var vpc_cidr = fmt.Sprintf("10.0.%d.0/%d", count, vpc_cidr_mask)
			vpc, err := awsxec2.NewVpc(ctx, vpc_name, &awsxec2.VpcArgs{
				Tags: pulumi.StringMap{
					"Name": pulumi.String(vpc_name),
				},
				CidrBlock:                 &vpc_cidr,
				NumberOfAvailabilityZones: pulumi.IntRef(vpc_az_count),
				SubnetSpecs: []awsxec2.SubnetSpecArgs{
					{
						Type:     awsxec2.SubnetTypePublic,
						CidrMask: pulumi.IntRef(vpc_subnet_cidr_mask),
					},
					{
						Type:     awsxec2.SubnetTypePrivate,
						CidrMask: pulumi.IntRef(vpc_subnet_cidr_mask),
					},
				},
			})
			if err != nil {
				return err
			}
			vpc_ids = append(vpc_ids, vpc.VpcId.ToStringOutput())

			// Security Groups
			var security_group_name = fmt.Sprintf("%s-sg-%02d", prefix, count)
			sg, err := awsec2.NewSecurityGroup(ctx, security_group_name, &awsec2.SecurityGroupArgs{
				VpcId: vpc.VpcId,
				Tags: pulumi.StringMap{
					"Name": pulumi.String(security_group_name),
				},
				Ingress: awsec2.SecurityGroupIngressArray{
					&awsec2.SecurityGroupIngressArgs{
						FromPort: pulumi.Int(22), // SSH port with access to VPN
						ToPort:   pulumi.Int(22),
						Protocol: pulumi.String("tcp"),
						CidrBlocks: pulumi.StringArray{
							pulumi.String(sg_vpn_cidr),
						},
					},
					&awsec2.SecurityGroupIngressArgs{
						FromPort: pulumi.Int(22), // SSH port with access to local VPC CIDR
						ToPort:   pulumi.Int(22),
						Protocol: pulumi.String("tcp"),
						CidrBlocks: pulumi.StringArray{
							pulumi.String(vpc_cidr), // <- This value should be your vpn cidr range
						},
					},
				},
				Egress: awsec2.SecurityGroupEgressArray{
					awsec2.SecurityGroupEgressArgs{
						CidrBlocks: pulumi.StringArray{
							pulumi.String("0.0.0.0/0"),
						},
						Protocol: pulumi.String("-1"),
						FromPort: pulumi.Int(0),
						ToPort:   pulumi.Int(0),
					},
				},
			})
			if err != nil {
				return err
			}
			sg_ids = append(sg_ids, sg.ID())

			// Create EC2 instances
			for count := range ec2_vpc_count {
				var instance_name = fmt.Sprintf("%s-vm-%02d", vpc_name, count)
				vm, err := awsec2.NewInstance(ctx, instance_name, &awsec2.InstanceArgs{
					Ami:                      pulumi.String(ubuntu.Id),
					InstanceType:             pulumi.String("t2.micro"),
					KeyName:                  pulumi.String(*keyPair.KeyName),
					SubnetId:                 vpc.PublicSubnetIds.Index(pulumi.Int(0)),
					AssociatePublicIpAddress: pulumi.Bool(true),
					VpcSecurityGroupIds:      pulumi.StringArray{sg.ID()},
					Tags: pulumi.StringMap{
						"Name": pulumi.String(instance_name),
					},
				})
				if err != nil {
					return err
				}
				vm_host_names = append(vm_host_names, vm.PublicIp)
			}
		}
		// Return vpc and sg ids
		ctx.Export("vpc_ids", vpc_ids)
		ctx.Export("sg_ids", sg_ids)
		ctx.Export("vm_ip_addresses", vm_host_names)
		ctx.Export("keypair_name", pulumi.String(*keyPair.KeyName))
		ctx.Export("keypair_fingerprint", pulumi.String(keyPair.Fingerprint))

		return nil
	})
}
