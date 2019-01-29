using System;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Authentication;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using Microsoft.Azure.Management.Network.Fluent;
using Microsoft.Azure.Management.Network.Fluent.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.Graph.RBAC.Fluent;
using System.Linq;
using System.Collections.Generic;

namespace csharptest
{
    class Program
    {
        private static IAzure azure;
        private static INetwork vnet;
        private static INetworkSecurityGroup lockedNsg;
        private static INetworkSecurityGroup openNsg;

        static void Main(string[] args)
        {
            var subscriptionId = "<Subscription ID>";
            var sandboxNumber = 17;
            var studyNumber = 0;
            var podNumber = 0;
            azure = Azure.Authenticate("my.azureauth").WithSubscription(subscriptionId);;
            foreach (var rgName in azure.ResourceGroups.List().Select(rg => rg.Name)){
                //Console.WriteLine(rgName);
            }
            CreateSandbox(sandboxNumber);
            CreateStudy(sandboxNumber, studyNumber);
            CreatePod(sandboxNumber, studyNumber, podNumber);
            CreatePod(sandboxNumber, studyNumber, podNumber+1);
            CreatePod(sandboxNumber, studyNumber, podNumber+2);
            LockPod(sandboxNumber, studyNumber, podNumber);
            LockPod(sandboxNumber, studyNumber, podNumber+2);
            DeletePod(sandboxNumber, studyNumber, podNumber+2);
            
        }

        static void CreateSandbox(int sandboxNumber){

        }
        
        static void CreateStudy(int sandboxNumber, int studyNumber){
            var rgName = $"Sandbox{sandboxNumber}-Study{studyNumber}-CommonComponents";
            Console.WriteLine($"Creating resource group with name: {rgName}");
            azure.ResourceGroups
                        .Define(rgName)
                        .WithRegion(Region.EuropeNorth)
                        .Create();
            

            var openNsgName = "OpenPod";
            Console.WriteLine($"Creating NSG: {openNsgName}");
            openNsg = azure.NetworkSecurityGroups
                        .Define(openNsgName)
                        .WithRegion(Region.EuropeNorth)
                        .WithExistingResourceGroup(rgName)
                        .DefineRule("AllowRdp")
                            .AllowInbound()
                            .FromAnyAddress()
                            .FromPort(3389)
                            .ToAnyAddress()
                            .ToPort(3389)
                            .WithProtocol(SecurityRuleProtocol.Tcp)
                            .WithPriority(1300)
                            .WithDescription("Allow RDP")
                            .Attach()
                        .Create();

            var lockedNsgName = "LockedPod";
            Console.WriteLine($"Creating NSG: {lockedNsgName}");
            lockedNsg = azure.NetworkSecurityGroups
                        .Define(lockedNsgName)
                        .WithRegion(Region.EuropeNorth)
                        .WithExistingResourceGroup(rgName)
                        .DefineRule("BlockAllOutbound")
                            .DenyOutbound()
                            .FromAnyAddress()
                            .FromAnyPort()
                            .ToAnyAddress()
                            .ToAnyPort()
                            .WithAnyProtocol()
                            .WithPriority(1000)
                            .WithDescription("Block All Outbound Traffic")
                            .Attach()
                        .DefineRule("BlockAllInbound")
                            .DenyInbound()
                            .FromAnyAddress()
                            .FromAnyPort()
                            .ToAnyAddress()
                            .ToAnyPort()
                            .WithAnyProtocol()
                            .WithPriority(1000)
                            .WithDescription("Block All Inbound Traffic")
                            .Attach()
                        .Create();

            var vnetName = $"Sandbox{sandboxNumber}-Study{studyNumber}-Vnet";
            Console.WriteLine($"Creating virtual network with name: {vnetName}");
            vnet = azure.Networks
                        .Define(vnetName)
                        .WithRegion(Region.EuropeNorth)
                        .WithExistingResourceGroup(rgName)
                        .WithAddressSpace("10.0.0.0/16")
                        .DefineSubnet("gateway")
                            .WithAddressPrefix("10.0.255.0/24")
                            .WithExistingNetworkSecurityGroup(openNsg)
                            .Attach()
                        .Create();

        }

        static void CreatePod(int sandboxNumber, int studyNumber, int podNumber){
            var rgName = $"Sandbox{sandboxNumber}-Study{studyNumber}-Pod{podNumber}";
            Console.WriteLine($"Creating resource group with name: {rgName}");
            var resourceGroup = azure.ResourceGroups
                        .Define(rgName)
                        .WithRegion(Region.EuropeNorth)
                        .Create();
            
            Console.WriteLine($"Adding subnet with adressprefix 10.1.{podNumber}.0/24 to vnet");
            vnet.Update()
                .DefineSubnet(rgName)
                        .WithAddressPrefix($"10.0.{podNumber}.0/24")
                        .WithExistingNetworkSecurityGroup(openNsg)
                        .Attach()
                .Apply();
            
            //Commented out due to error message from authentication:
            //Unhandled Exception: Microsoft.Azure.Management.Graph.RBAC.Fluent.Models.GraphErrorException: Operation returned an invalid status code 'Forbidden'
            //
            //azure.AccessManagement.RoleAssignments
            //    .Define("8edcc958-5af1-4b8a-b2cb-5c0c136dd64a")
            //    .ForUser("t_fmell@statoil.net")// to be replaced by security group with .ForGroup(activeDirectoryGroup)
            //    .WithBuiltInRole(BuiltInRole.VirtualMachineContributor)// to be replaced with .WithRoleDefinition(customRoleId)
            //    .WithResourceGroupScope(resourceGroup)
            //    .Create();
            
        }

        static void LockPod(int sandboxNumber, int studyNumber, int podNumber){
            var subnetName = $"Sandbox{sandboxNumber}-Study{studyNumber}-Pod{podNumber}";
            Console.WriteLine($"Locking pod: {subnetName}");
            vnet.Update()
                .UpdateSubnet(subnetName)
                .WithExistingNetworkSecurityGroup(lockedNsg);
        }

        static void DeletePod(int sandboxNumber, int studyNumber, int podNumber){
            var rgName = $"Sandbox{sandboxNumber}-Study{studyNumber}-Pod{podNumber}";
            Console.WriteLine($"Removing resource group: {rgName}");
            azure.ResourceGroups.DeleteByName(rgName);

            Console.WriteLine($"Removing subnet: {rgName}");
            vnet.Update().WithoutSubnet(rgName).Apply();
        }
    }
}
