## Scaling AI/ML Workloads with Rafay and AI on EKS

**Introduction:**

Running large-scale AI/ML workloads on Kubernetes offers immense power, but managing the underlying infrastructure can be complex. To address this, AWS provides "AI on EKS," a best-practice reference architecture for deploying robust AI/ML environments. Our primary objective was to leverage this expert-built foundation and make it easily accessible for our internal teams. We achieved this by transforming the AI on EKS Terraform stack into modular Rafay Resource and Environment Templates. This work enables scalable, consistent, and reusable deployment of complex AI/ML stacks, turning a powerful architecture into a self-service capability for developers across the organization.

**What is AI on EKS?**

AI on EKS is a solution designed by AWS to make it easier to run scalable AI/ML workloads on Amazon EKS. It provides pre-configured components and best practices, addressing common challenges such as:

*   **Infrastructure Provisioning:** Automating the setup of necessary resources (compute, storage, networking).
*   **Job Management:** Orchestrating and scheduling training and inference jobs.
*   **Resource Management:** Efficiently allocating and utilizing resources.
*   **Monitoring and Logging:** Tracking the performance and health of workloads.

The AI on EKS solution includes Terraform code that allows users to define and provision the required infrastructure as code, ensuring consistency and repeatability.

**Value Proposition: Leveraging Established Architectures**
**Technical Deep Dive into the AI on EKS Infrastructure**

The AI on EKS infrastructure, as implemented using Rafay templates, is structured into distinct stages, each building upon the previous one:

1.  **Networking:** This foundational layer establishes the network environment for the EKS cluster. Key aspects include:
    *   **VPC:** A dedicated Virtual Private Cloud (VPC) isolates the EKS cluster and its resources.
    *   **Subnets:** Public and private subnets are configured across the Availability Zones (AZs) available in the selected AWS region (`aws_region`). The number and CIDR ranges of public and private subnets are determined by the `public_subnets` and `private_subnets` variables, respectively. Public subnets house internet-facing resources like load balancers, while private subnets contain the EKS worker nodes and are tagged for Karpenter discovery.
    *   **Route Tables:** These control network traffic flow within the VPC and to external networks.
    *   **Security Groups:** Firewall rules control inbound and outbound traffic. Specific rules are managed by the EKS module, with additional rules allowing all traffic between nodes on ephemeral ports and from the cluster API to node groups.

2.  **EKS Cluster:** This stage provisions the EKS cluster itself, utilizing the networking components defined previously. Important configurations include:
    *   **Kubernetes Version:** The `eks_cluster_version` variable specifies the Kubernetes version for the cluster.
    *   **Control Plane Configuration:** Settings for the EKS control plane, such as logging and audit configuration.
    *   **Node Groups:** Define the compute resources for the cluster, including:
        *   **Core Node Group:** A managed node group named "core-node-group" is created for hosting essential system addons. It uses the `AL2023_x86_64_STANDARD` AMI type, instance types specified by the `core_node_instance_types` variable, and has a configurable size controlled by `core_node_min_size`, `core_node_max_size`, and `core_node_desired_size`.  It includes a taint to ensure only critical addons run on these nodes.
        *   **General Purpose Node Group:** A managed node group named "general-purpose-group" for general workloads and third-party agents. It uses `AL2023_x86_64_STANDARD` AMI, `t3.xlarge` instance types and has a configurable size controlled by `min_size = 1`, `max_size = 2`, and `desired_size   = 1`.
        *   **IAM Roles:** Two IAM roles are created for CloudWatch Observability and EBS CSI Driver, allowing the cluster to interact with these AWS services.

3.  **Addons:** This layer installs additional tools and components to enhance the EKS cluster's functionality, particularly for AI/ML workloads. Examples include:
    *   **Core Addons (EKS Blueprints):** This module installs foundational addons using the `eks-blueprints-addons` module. These include:
        *   **AWS Load Balancer Controller:** Enables the management of AWS load balancers for Kubernetes services.
        *   **AWS EFS CSI Driver:** Allows Kubernetes pods to access and use AWS Elastic File System (EFS) volumes.
        *   **Ingress NGINX:** An ingress controller that manages external access to services in the cluster.
        *   **Kube-Prometheus-Stack:** Provides a complete monitoring solution with Prometheus for metrics collection, Grafana for visualization, and Alertmanager for alerting.
        *   **Karpenter Controller:** Installs the Karpenter controller for dynamic node provisioning.
    *   **Data & AI Addons (EKS Data Addons):**  This module, using the `eks-data-addons` module, installs AI/ML-specific tools:
        *   **Volcano:** A batch scheduler designed for high-performance computing and AI/ML workloads.
        *   **KubeRay Operator:**  Deploys the KubeRay operator for managing Ray clusters, configured to use Volcano for scheduling.
        *   **Kubecost:**  A tool for monitoring and managing Kubernetes costs, configured to integrate with the Prometheus instance installed by the core addons.
        *   **Karpenter Resources:** Creates default Karpenter NodePool and EC2NodeClass resources.
            *   **x86-cpu-karpenter:** Defines a NodePool for general-purpose x86-64 instances, allowing Karpenter to provision instances from the "c", "m", and "r" instance categories with generations greater than 4, using Bottlerocket AMIs and a mix of spot and on-demand capacity.
            *   **g5-gpu-karpenter:** Defines a NodePool for GPU-enabled instances, specifically targeting g5 and g4dn instance families, using Bottlerocket AMIs and on-demand capacity. It also configures taints to ensure only pods requiring GPUs are scheduled on these nodes.
    *   **Storage:** Configures `gp3` as the default storage class, disabling `gp2`.


This layered approach, managed through Rafay templates, ensures a modular, consistent, and repeatable deployment process for AI/ML workloads on EKS.

**Rafay Platform: Simplifying Kubernetes Management**

The Rafay Platform streamlines Kubernetes application and environment management, offering features such as centralized control, consistent environment definitions, and streamlined application lifecycle management. It achieves this through reusable **Resource Templates** (defining Kubernetes resources) and **Environment Templates** (specifying complete environments), ensuring consistency across deployments.

**Transforming AI on EKS with Rafay Templates:**

By transforming the AI on EKS Terraform code into Rafay Resource and Environment Templates, we can achieve the following benefits:

1.  **Simplified Deployment:**  Rafay templates enable self-service deployment of the AI on EKS stack. Users select an Environment Template, configure parameters, and Rafay automates infrastructure provisioning and AI/ML component deployment.
2.  **Increased Consistency:**  Templates ensure consistent deployments across teams and projects, minimizing configuration drift.
3.  **Improved Scalability:**  Rafay's centralized management facilitates scaling AI/ML workloads across clusters and regions.
4.  **Enhanced Governance:**  Templates enable policy enforcement for compliance and security.
5.  **Leveraging Established Architectures:** This approach allows us to integrate official and open-source architectures and best practices into our workflows, avoiding unnecessary reinvention.



**Value for Internal Developer Portal:**

Integrating Rafay templates with an internal developer portal empowers teams to:

*   **Self-Service Provisioning:** Developers can independently provision and manage AI/ML environments without requiring manual infrastructure setup.
*   **Faster Onboarding:** New teams can quickly onboard and deploy AI/ML workloads using pre-defined, consistent templates.
*   **Reduced Operational Overhead:** The Rafay platform handles much of the infrastructure management, freeing up developers to focus on building and improving AI/ML models.

**Conclusion:**

Transforming the AI on EKS Terraform stack into Rafay Resource and Environment Templates streamlines the deployment and management of AI/ML workloads, enabling organizations to scale their AI initiatives more effectively and empower their development teams through self-service capabilities within an internal developer portal.