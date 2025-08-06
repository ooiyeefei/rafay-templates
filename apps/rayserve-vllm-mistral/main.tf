# 1. Define the Namespace for the application
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }
}

# 2. Define the Secret for the Hugging Face Hub token
# The value is taken from the input variable and base64 encoded as required by Kubernetes.
resource "kubernetes_secret" "hf_token" {
  depends_on = [kubernetes_namespace.this]

  metadata {
    name      = "hf-token"
    namespace = var.namespace
  }

  data = {
    "hf-token" = base64encode(var.hugging_face_hub_token)
  }

  type = "Opaque"
}

# 3. Define the RayService Custom Resource
# The kubernetes_manifest resource is used to deploy the complex RayService YAML.
# This approach maintains the exact structure of your original file.
resource "kubernetes_manifest" "ray_service" {
  depends_on = [kubernetes_secret.hf_token]

  manifest = {
    "apiVersion" = "ray.io/v1"
    "kind"       = "RayService"
    "metadata" = {
      "name"      = "vllm"
      "namespace" = var.namespace
    }
    "spec" = {
      "serviceUnhealthySecondThreshold"  = 1800
      "deploymentUnhealthySecondThreshold" = 1800
      "serveConfigV2" = yamlencode({
        "applications" = [
          {
            "name"        = "mistral"
            "import_path" = "vllm_serve:deployment"
            "runtime_env" = {
              "env_vars" = {
                "LD_LIBRARY_PATH"        = "/home/ray/anaconda3/lib:$LD_LIBRARY_PATH"
                "MODEL_ID"               = "mistralai/Mistral-7B-Instruct-v0.2"
                "GPU_MEMORY_UTILIZATION" = "0.9"
                "MAX_MODEL_LEN"          = "8192"
                "MAX_NUM_SEQ"            = "4"
                "MAX_NUM_BATCHED_TOKENS" = "32768"
              }
            }
            "deployments" = [
              {
                "name" = "mistral-deployment"
                "autoscaling_config" = {
                  "metrics_interval_s"                       = 0.2
                  "min_replicas"                             = 1
                  "max_replicas"                             = 4
                  "look_back_period_s"                       = 2
                  "downscale_delay_s"                        = 600
                  "upscale_delay_s"                          = 30
                  "target_num_ongoing_requests_per_replica" = 20
                }
                "graceful_shutdown_timeout_s" = 5
                "max_concurrent_queries"      = 100
                "ray_actor_options" = {
                  "num_cpus" = 1
                  "num_gpus" = 1
                }
              }
            ]
          }
        ]
      })
      "rayClusterConfig" = {
        "rayVersion"              = "2.24.0"
        "enableInTreeAutoscaling" = true
        "headGroupSpec" = {
          "headService" = {
            "metadata" = {
              "name"      = "vllm"
              "namespace" = var.namespace
            }
          }
          "rayStartParams" = {
            "dashboard-host" = "0.0.0.0"
            "num-cpus"       = "0"
          }
          "template" = {
            "spec" = {
              "containers" = [
                {
                  "name"            = "ray-head"
                  "image"           = "public.ecr.aws/data-on-eks/ray2.24.0-py310-vllm-gpu:v1"
                  "imagePullPolicy" = "IfNotPresent"
                  "lifecycle" = {
                    "preStop" = {
                      "exec" = {
                        "command" = ["/bin/sh", "-c", "ray stop"]
                      }
                    }
                  }
                  "ports" = [
                    { "containerPort" = 6379, "name" = "gcs" },
                    { "containerPort" = 8265, "name" = "dashboard" },
                    { "containerPort" = 10001, "name" = "client" },
                    { "containerPort" = 8000, "name" = "serve" }
                  ]
                  "volumeMounts" = [
                    { "mountPath" = "/tmp/ray", "name" = "ray-logs" }
                  ]
                  "resources" = {
                    "limits" = { "cpu" = "2", "memory" = "12G" }
                    "requests" = { "cpu" = "2", "memory" = "12G" }
                  }
                  "env" = [
                    { "name" = "VLLM_PORT", "value" = "8004" },
                    { "name" = "LD_LIBRARY_PATH", "value" = "/home/ray/anaconda3/lib:$LD_LIBRARY_PATH" },
                    {
                      "name" = "HUGGING_FACE_HUB_TOKEN",
                      "valueFrom" = {
                        "secretKeyRef" = { "name" = kubernetes_secret.hf_token.metadata[0].name, "key" = "hf-token" }
                      }
                    },
                    { "name" = "RAY_GRAFANA_HOST", "value" = "http://kube-prometheus-stack-grafana.kube-prometheus-stack.svc:80" },
                    { "name" = "RAY_PROMETHEUS_HOST", "value" = "http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc:9090" }
                  ]
                }
              ]
              "nodeSelector" = {
                "NodeGroupType" = "x86-cpu-karpenter"
                "type"          = "karpenter"
              }
              "volumes" = [
                { "name" = "ray-logs", "emptyDir" = {} }
              ]
            }
          }
        }
        "workerGroupSpecs" = [
          {
            "replicas"       = 1
            "minReplicas"    = 1
            "maxReplicas"    = 4
            "groupName"      = "gpu-group"
            "rayStartParams" = {}
            "template" = {
              "spec" = {
                "containers" = [
                  {
                    "name"            = "ray-worker"
                    "image"           = "public.ecr.aws/data-on-eks/ray2.24.0-py310-vllm-gpu:v1"
                    "imagePullPolicy" = "IfNotPresent"
                    "lifecycle" = {
                      "preStop" = {
                        "exec" = { "command" = ["/bin/sh", "-c", "ray stop"] }
                      }
                    }
                    "resources" = {
                      "limits"   = { "cpu" = "10", "memory" = "48G", "nvidia.com/gpu" = "1" }
                      "requests" = { "cpu" = "10", "memory" = "48G", "nvidia.com/gpu" = "1" }
                    }
                    "env" = [
                      { "name" = "VLLM_PORT", "value" = "8004" },
                      { "name" = "LD_LIBRARY_PATH", "value" = "/home/ray/anaconda3/lib:$LD_LIBRARY_PATH" },
                      {
                        "name" = "HUGGING_FACE_HUB_TOKEN",
                        "valueFrom" = {
                          "secretKeyRef" = { "name" = kubernetes_secret.hf_token.metadata[0].name, "key" = "hf-token" }
                        }
                      }
                    ]
                  }
                ]
                "nodeSelector" = {
                  "NodeGroupType" = "g5-gpu-karpenter"
                  "type"          = "karpenter"
                }
                "tolerations" = [
                  { "key" = "nvidia.com/gpu", "operator" = "Exists", "effect" = "NoSchedule" }
                ]
              }
            }
          }
        ]
      }
    }
  }
}