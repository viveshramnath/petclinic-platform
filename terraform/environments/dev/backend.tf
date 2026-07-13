# Remote state backend — dev environment.
#
# `bucket` is intentionally omitted here: the bucket name embeds the AWS
# account ID (petclinic-terraform-state-{account-id}), which is only known
# after running scripts/bootstrap-state.sh. Supply it as partial
# configuration at init time:
#
#   terraform init -backend-config="bucket=petclinic-terraform-state-<account-id>"
#
# or via a gitignored backend-config.hcl file:
#
#   terraform init -backend-config=backend-config.hcl

terraform {
  backend "s3" {
    key            = "petclinic/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
