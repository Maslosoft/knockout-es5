
# Static utility functions
# ------------------------
#
# Since Knockout-ES5 sets up properties that return values, not observables, you can't
# trivially subscribe to the underlying observables (e.g., `someProperty.subscribe(...)`),
# or tell them that object values have mutated, etc. To handle this, we set up some
# extra utility functions that can return or work with the underlying observables.
# Returns the underlying observable associated with a model property (or `null` if the
# model or property doesn't exist, or isn't associated with an observable). This means
# you can subscribe to the property, e.g.:
#
#     ko.getObservable(model, 'propertyName')
#       .subscribe(function(newValue) { ... });

getObservable = (obj, propertyName) ->
  if !obj or typeof obj != 'object'
    return null
  allObservablesForObject = getAllObservablesForObject(obj, false)
  if allObservablesForObject and propertyName of allObservablesForObject
    return allObservablesForObject[propertyName]()
  null

# Returns a boolean indicating whether the property on the object has an underlying
# observables. This does the check in a way not to create an observable if the
# object was created with lazily created observables

isTracked = (obj, propertyName) ->
  if !obj or typeof obj != 'object'
    return false
  allObservablesForObject = getAllObservablesForObject(obj, false)
  ! !allObservablesForObject and propertyName of allObservablesForObject

# Causes a property's associated observable to fire a change notification. Useful when
# the property value is a complex object and you've modified a child property.

valueHasMutated = (obj, propertyName) ->
  observable = getObservable(obj, propertyName)
  if observable
    observable.valueHasMutated()
  return