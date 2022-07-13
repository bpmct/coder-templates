provider "coder" {

}

data "coder_workspace" {

}

provider "oci" {
  region = "us-phoenix-1"
}

resource "oci_core_instance" "dev" {

}
