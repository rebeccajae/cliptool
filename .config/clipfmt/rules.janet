(def- rules @[])

(defn defrule [name trigger matcher & transforms]
  (array/push rules {:name name
                     :trigger trigger
                     :matcher matcher
                     :transforms transforms}))


# This can be whatever you want. It returns a list of applicable rules
# given some input. The strings can be anything you want.
(defn evaluate-rules [input]
  (def always @[])
  (def manual @[])
  (each rule rules
    (when ((rule :matcher) input)
      (if (= (rule :trigger) :always)
        (array/push always (rule :name))
        (array/push manual (rule :name)))))
  {:always always :manual manual})

# This is also called by the binary when a rule is selected. The name variable
# will always be a value that was returned by evaluate-rules, and the input is
# whatever is on the clipboard (again, same as evaluate-rules' input value)
(defn apply-rule [name input]
  (def rule (find |(= ($ :name) name) rules))
  (when rule
    (reduce |(($1) $0) input (rule :transforms))))

# Rules
(defrule "Format JSON" :always json/valid? json/pretty)

