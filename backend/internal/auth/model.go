package auth


type RegisterInput struct {
    Username    string `json:"username"`
    DisplayName string `json:"display_name"`
    Password    string `json:"password"`
}
