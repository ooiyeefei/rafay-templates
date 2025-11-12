resource "null_resource" "setup" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod +x ./setup.sh; ./setup.sh"
  }
}


resource "null_resource" "runai" {
  depends_on = [null_resource.setup]
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "chmod +x ./runai.sh; ./runai.sh"
    environment = {
      CLUSTER = var.cluster
      APP     = var.app
      USER    = var.user
      ROLE    = var.role
    }
  }
}

data "local_file" "cluster-uuid" {
  depends_on = [null_resource.runai]
  filename   = "uuid"
}

data "local_file" "user-password" {
  depends_on = [null_resource.runai]
  filename   = "password"
}
