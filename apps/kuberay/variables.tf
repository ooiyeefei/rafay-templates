# --- Cluster & Rafay ---
variable "cluster_name" {
  description = "Name of the EKS cluster to deploy to."
  type        = string
}

variable "project_name" {
  description = "Rafay Project Name."
  type        = string
}

# --- Shared Infrastructure ---
variable "shared_alb_hostname" {
  description = "The public DNS name of the shared Application Load Balancer for the cluster."
  type        = string
}

# --- KubeRay Helm Chart Configuration ---
variable "kuberay_version" {
  description = "Version of the KubeRay Helm charts to use."
  type        = string
  default     = "1.1.2"
}

variable "volcano_version" {
  description = "Version of the Volcano scheduler Helm chart."
  type        = string
  default     = "1.11.0"
}

variable "enable_volcano" {
  description = "Set to 'true' to enable the Volcano batch scheduler."
  type        = string
  default     = "true"
}

# --- KubeRay Cluster Configuration ---
variable "kuberay_head_config" {
  description = "Optional: Configuration for the Ray head node's CPU and memory."
  type        = map(string)
  default = {
    cpu_request    = "500m"  # 0.5 CPU core
    memory_request = "1Gi"   # 1 Gibibyte RAM
    cpu_limit      = "1"     # 1 CPU core
    memory_limit   = "2Gi"   # 2 Gibibytes RAM
  }
}

variable "kuberay_worker_config" {
  description = "Optional: Configuration for the Ray worker nodes' CPU and memory."
  type        = map(string)
  default = {
    cpu_request    = "500m"
    memory_request = "1Gi"
    cpu_limit      = "1"
    memory_limit   = "2Gi"
  }
}

# --- OPTIONAL: Advanced Scheduling ---
variable "kuberay_worker_tolerations" {
  description = "Optional: A list of tolerations to apply to Ray worker pods, allowing them to run on tainted nodes (e.g., GPU nodes)."
  type        = list(any)
  default     = null # If unspecified, no tolerations will be applied.
}

variable "kuberay_worker_node_selector" {
  description = "Optional: A map of key-value pairs for node selection, forcing Ray workers to run on nodes with specific labels."
  type        = map(string)
  default     = null # If unspecified, workers can run on any node.
}

# --- Kubeconfig Variables (Injected from a preceding kubeconfig module) ---
variable "host" {
  description = "The Kubernetes API server endpoint."
  type        = string
  sensitive   = true
}
variable "clientcertificatedata" {
  description = "The client certificate data for Kubernetes authentication."
  type        = string
  sensitive   = true
}
variable "clientkeydata" {
  description = "The client key data for Kubernetes authentication."
  type        = string
  sensitive   = true
}
variable "certificateauthoritydata" {
  description = "The certificate authority data for the Kubernetes cluster."
  type        = string
  sensitive   = true
}