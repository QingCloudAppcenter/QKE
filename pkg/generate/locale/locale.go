package locale

func GetLocal() ([]byte, error) {
	return []byte(QKELocale), nil
}
