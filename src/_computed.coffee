# Computed properties
# -------------------
#
# The preceding code is already sufficient to upgrade ko.computed model properties to ES5
# getter/setter pairs (or in the case of readonly ko.computed properties, just a getter).
# These then behave like a regular property with a getter function, except they are smarter:
# your evaluator is only invoked when one of its dependencies changes. The result is cached
# and used for all evaluations until the next time a dependency changes).
#
# However, instead of forcing developers to declare a ko.computed property explicitly, it's
# nice to offer a utility function that declares a computed getter directly.
# Implements `ko.defineProperty`

defineComputedProperty = (obj, propertyName, evaluatorOrOptions) ->
  ko = this
  computedOptions =
    owner: obj
    deferEvaluation: true
  if typeof evaluatorOrOptions == 'function'
    computedOptions.read = evaluatorOrOptions
  else
    if 'value' of evaluatorOrOptions
      throw new Error('For ko.defineProperty, you must not specify a "value" for the property. ' + 'You must provide a "get" function.')
    if typeof evaluatorOrOptions.get != 'function'
      throw new Error('For ko.defineProperty, the third parameter must be either an evaluator function, ' + 'or an options object containing a function called "get".')
    computedOptions.read = evaluatorOrOptions.get
    computedOptions.write = evaluatorOrOptions.set
  obj[propertyName] = ko.computed(computedOptions)
  track.call ko, obj, [ propertyName ]
  obj

