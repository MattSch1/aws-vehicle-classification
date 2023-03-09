variable "probability_threshold" {
  type        = number
  description = "Probability threshold for Rekognition to accept a label"
}

variable "accepted_labels" {
  type        = string
  description = "List of labels that are accepted"
}

variable "password" {
  type        = string
  description = "Password to get the bearer token for the Autosled API"
}
