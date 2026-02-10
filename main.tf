terraform {
  required_providers {
    docker = {
      source  = "registry.terraform.io/kreuzwerker/docker"
      version = "~>3.0"
    }

    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~>3.5"
    }
  }
}

provider "random" {}
provider "docker" {}

variable "port" {
  type    = number
  default = null
}

variable "network_mode" {
  type    = string
  default = "bridge"
}

variable "persist_data" {
  type    = bool
  default = true
}

variable "data_path" {
  type        = string
  description = "Host path to persist data in case of persist_data is true."
  default     = null

}

variable "docker_image" {
  type    = string
  default = "novopattern/postgres:14.9-alpine-pgvector"
}

variable "dbname" {
  type        = string
  description = "Fixed database name. If not provided, a random name is generated."
  default     = null
}

variable "hereyaDockerNetwork" {
  type    = string
  default = null
}

locals {
  dbname = var.dbname != null ? var.dbname : random_pet.dbname.id
  volumes = var.persist_data ? [
    {
      container_path = "/var/lib/postgresql/data"
      host_path      = var.data_path != null ? pathexpand("${var.data_path}") : abspath("${path.module}/${local.dbname}")
      read_only      = false
    }
  ] : []
}

resource "random_pet" "dbname" {
  length = 1
}

resource "docker_image" "postgres" {
  name         = var.docker_image
  keep_locally = true
}

resource "docker_container" "postgres" {
  image        = docker_image.postgres.image_id
  name         = random_pet.dbname.id
  network_mode = var.network_mode
  ports {
    internal = 5432
    external = var.port
  }

  env = [
    "POSTGRES_PASSWORD=${local.dbname}",
    "POSTGRES_USER=${local.dbname}",
    "POSTGRES_DB=${local.dbname}"
  ]

  dynamic "networks_advanced" {
    for_each = var.hereyaDockerNetwork != null ? [var.hereyaDockerNetwork] : []
    content {
      name = networks_advanced.value
    }
  }

  dynamic "volumes" {
    for_each = local.volumes
    content {
      container_path = volumes.value["container_path"]
      host_path      = volumes.value["host_path"]
      read_only      = volumes.value["read_only"]
    }
  }
}

locals {
  port = var.network_mode == "host" ?  5432 : docker_container.postgres.ports[0].external
}

output "POSTGRES_URL" {
  sensitive = true
  value     = "postgresql://${local.dbname}:${local.dbname}@localhost:${local.port}/${local.dbname}"
}

output "POSTGRES_ROOT_URL" {
  sensitive = true
  value     = "postgresql://${local.dbname}:${local.dbname}@localhost:${local.port}"
}

output "HEREYA_DOCKER_POSTGRES_URL" {
  sensitive = true
  value     = "postgresql://${local.dbname}:${local.dbname}@${docker_container.postgres.name}:5432/${local.dbname}"
}

output "HEREYA_DOCKER_POSTGRES_ROOT_URL" {
  sensitive = true
  value     = "postgresql://${local.dbname}:${local.dbname}@${docker_container.postgres.name}:5432"
}

output "DBNAME" {
  sensitive = true
  value     = local.dbname
}
