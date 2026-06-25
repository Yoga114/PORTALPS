provider "aws" {
  region = "ap-southeast-3"
}

# Windows Server 2022 Latest AMI
data "aws_ssm_parameter" "windows2022" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

data "aws_availability_zones" "available" {}

# ─── VPC ──────────────────────────────────────────────────────────────────────
module "VPC" {
  source               = "./modules/VPC"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones   = data.aws_availability_zones.available.names
}

# ─── S3 Installer + IAM Role ──────────────────────────────────────────────────
module "S3_INSTALLER" {
  source      = "./modules/S3_INSTALLER"
  bucket_name = "arcgis-installer-bucket"
}

# ─── EC2: PSAGE — Windows — ArcGIS Portal + Server ───────────────────────────
module "EC2_PSAGE" {
  source               = "./modules/EC2"
  ami_id               = data.aws_ssm_parameter.windows2022.value # Windows 2022
  instance_type        = "t2.micro"
  instance_name        = "PSAGE"
  key_name             = "key-age"
  volume_size          = "30"
  volume_type          = "gp3"
  subnet_id            = module.VPC.private_subnet_ids[0]
  vpc_id               = module.VPC.vpc_id
  iam_instance_profile = module.S3_INSTALLER.instance_profile_name
  private_ip           = "10.0.4.10"   # ← custom IP

  user_data = templatefile("${path.root}/script/PSAGE.ps1.tmpl", {
    AWS_DEFAULT_REGION           = var.aws_default_region
    arcgis_enterprise_portal_install        = file("${path.root}/chef/PSAGE/Portal/arcgis-portal-install.json")
    arcgis_enterprise_portal_primary        = file("${path.root}/chef/PSAGE/Portal/arcgis-portal-primary.json")
    arcgis_enterprise_server_install        = file("${path.root}/chef/PSAGE/Server/arcgis-server-install.json")
    arcgis_enterprise_server                = file("${path.root}/chef/PSAGE/Server/arcgis-server.json")
    arcgis_enterprise_server_federation     = file("${path.root}/chef/PSAGE/Server/gis-server-federation.json")
    arcgis_enterprise_ds_install            = file("${path.root}/chef/PSAGE/Relational/arcgis-datastore-install.json")
    arcgis_enterprise_ds_primary            = file("${path.root}/chef/PSAGE/Relational/arcgis-datastore-relational-primary.json")
    arcgis_enterprise_image_federation      = file("${path.root}/chef/PSAGE/Imagery/imagehosting-federation.json")
  })

  ingress_rules = [
    {
      description = "HTTP from ALB"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from ALB"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "WinRM HTTP (provisioner)"
      from_port   = 5985
      to_port     = 5985
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "WinRM HTTPS (provisioner)"
      from_port   = 5986
      to_port     = 5986
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "RDP admin access"
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "ArcGIS Web Adaptor HTTP"
      from_port   = 6080
      to_port     = 6080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "ArcGIS Web Adaptor HTTPS"
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
  ]
}

# ─── EC2: PSSPATIO — Linux — ArcGIS Spatiotemporal DataStore ─────────────────
module "EC2_PSSPATIO" {
  source               = "./modules/EC2"
  ami_id               = "ami-0727fdbd8fb05e166" # Ubuntu 24.04 LTS
  instance_type        = "t2.micro"
  instance_name        = "PSSPATIO"
  key_name             = "key-spatio"
  volume_size          = "30"
  volume_type          = "gp3"
  subnet_id            = module.VPC.private_subnet_ids[1]
  vpc_id               = module.VPC.vpc_id
  iam_instance_profile = module.S3_INSTALLER.instance_profile_name
  private_ip           = "10.0.5.10"   # ← custom IP

  user_data = templatefile("${path.root}/script/PSSPATIO.sh.tmpl", {
    AWS_DEFAULT_REGION           = var.aws_default_region
    arcgis_enterprise_ds_install = file("${path.root}/chef/PSSPATIO/Spasiotemporal/arcgis-datastore-install.json")
    arcgis_enterprise_spatio     = file("${path.root}/chef/PSSPATIO/Spasiotemporal/arcgis-datastore-spatiotemporal.json")
  })

  ingress_rules = [
    {
      description = "SSH admin access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "ArcGIS Server HTTP"
      from_port   = 6080
      to_port     = 6080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "ArcGIS Server HTTPS"
      from_port   = 6443
      to_port     = 6443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "ArcGIS Server cluster communication"
      from_port   = 4000
      to_port     = 4002
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
  ]
}

# ─── EC2: PSGEOV — Linux — ArcGIS GeoEvent Server ────────────────────────────
module "EC2_PSGEOV" {
  source               = "./modules/EC2"
  ami_id               = "ami-0727fdbd8fb05e166" # Ubuntu 24.04 LTS
  instance_type        = "t2.micro"
  instance_name        = "PSGEOV"
  key_name             = "key-pesgeov"
  volume_size          = "30"
  volume_type          = "gp3"
  subnet_id            = module.VPC.private_subnet_ids[2]
  vpc_id               = module.VPC.vpc_id
  iam_instance_profile = module.S3_INSTALLER.instance_profile_name
  private_ip           = "10.0.6.10"   # ← custom IP

  user_data = templatefile("${path.root}/script/PSGEOV.sh.tmpl", {
    AWS_DEFAULT_REGION           = var.aws_default_region
    arcgis_enterprise_geoevent_install    = file("${path.root}/chef/PSGEOV/GeoEvent/geoevent-server-install.json")
    arcgis_enterprise_geoevent_server     = file("${path.root}/chef/PSGEOV/GeoEvent/geoevent-server.json")
    arcgis_enterprise_geoevent_federation = file("${path.root}/chef/PSGEOV/GeoEvent/geoevent-server-federation.json")
  })

  ingress_rules = [
    {
      description = "SSH admin access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Portal HTTP"
      from_port   = 7080
      to_port     = 7080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "Portal HTTPS"
      from_port   = 7443
      to_port     = 7443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "Portal HA inter-machine communication"
      from_port   = 7005
      to_port     = 7099
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
    {
      description = "Portal ephemeral/internal ports"
      from_port   = 11443
      to_port     = 11443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    },
  ]
}

# ─── ALB ──────────────────────────────────────────────────────────────────────
module "ALB" {
  source             = "./modules/ALB"
  vpc_id             = module.VPC.vpc_id
  public_subnet_ids  = module.VPC.public_subnet_ids
  target_instance_id = module.EC2_PSAGE.instance_id
  certificate_arn    = "arn:aws:acm:ap-southeast-3:123456789012:certificate/your-cert-id"
  domain             = "domain.com"
  hosted_zone_id     = "your-route53-hosted-zone-id"   # Ganti dengan Hosted Zone ID Route53 untuk domain.com
}
