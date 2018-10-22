provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "example" {
  ami           = "ami-0bdf93799014acdc4"
  instance_type = "t2.micro"

  tags {
    Name = "terraform-example"
  }
}
