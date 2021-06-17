extension AUValue {
    func truncate(places : Int)-> Double {
        return Double(floor(pow(10.0, Double(places)) * Double(self))/pow(10.0, Double(places)))
    }
}
