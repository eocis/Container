# Cidrs
variable "cidrs" {
  type = map(string)
  default = {
    0 = "10.0.0.0/24"
    1 = "10.0.1.0/24"
    2 = "10.0.2.0/24"
    3 = "10.0.3.0/24"
  }
}

# Instance Type
variable "instance" {
  type = map(string)
  default = {
    "Bastion"   = "t2.micro"
    "Front-End" = "t2.micro"
    "Back-End"  = "t2.micro"
  }

}

# Key Pair Name

variable "Bastion_Key" {
  type    = string
  default = "bastion_key"
}

variable "Front-End_Key" {
  type    = string
  default = "front-end_key"
}

variable "Back-End_Key" {
  type    = string
  default = "back-end_key"
}

# user_data
variable "Front-End_instance_template" { # Front-End Instance user_data configure
  type    = string
  default = <<EOF
#!/bin/bash -xe
apt update -y
apt install -y apache2
EOF
}

variable "Back-End_instance_template" { # Front-End Instance user_data configure
  type    = string
  default = <<EOF
#!/bin/bash -xe
apt update -y
apt install -y python3 python3-pip
pip3 install --upgrade pip
pip install flask
EOF
}

# Back-End Application Port
variable "Back-End_Port" {
  type    = number
  default = 8080
}

# Auto Scale
variable "Front-End_ASG" {
  type = map(string)
  default = {
    "MAX" = 4
    "MIN" = 2
  }
}

variable "Back-End_ASG" {
  type = map(string)
  default = {
    "MAX" = 4
    "MIN" = 2
  }
}

# Auto Scale Policy
variable "Front-End_ASG_Policy_AVGCPU" { # ASG Average CPU
  type    = number
  default = 80.0
}

variable "Back-End_ASG_Policy_AVGCPU" { # ASG Average CPU
  type    = number
  default = 80.0
}