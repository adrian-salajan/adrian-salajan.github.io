---
layout: post
title:  "The assignment operator is broken!"
date:   2020-10-02 15:13:25 -0500
categories: functional programming
---
Most programming languages have this operator `=` which is called the assignment operator.
Have you evered wondered why this is called assignment and not simply equals ?

You might think equals is already defined and you are probably thinking of `==`
but this is called "equal to", this one answers a question but assigment is an action, make a equal to b.

` val a = b `

I will try to show you this operator is broken or to be less dramatic,
one very popular paradigm of programming makes it look broken.

### The intuitive behavior
{% highlight scala %}

    val five = 5

    val fiveDoubled = five + five
    val fiveDoubledInline = 5 + 5

    assert(fiveDoubled == fiveDoubledInline) //true
{% endhighlight %}

Here the value 5 is assigned to the variable five. 
Next what follows are two possible programs to double the value.
We can reuse the `five` or use the actual definition of the variable (inlining).
Basically whenever we see `five` we copy-paste its definition `5`.

In the end I guess we can all agree and find it intuitive that by doing this copy-paste rewrite these programs are equivalent. 
Here we could really call `=` "equals" since it follows precisely the meaning of `=` in math:

`5 + x = 10` so then `x = 10 - 5` and replacing `x` in the first we can write 
`5 + 10 - 5  = 10`. All fine.

In math `=` really means equality, which is different from the assignment from programming.
  

### The problem

Let's replace `five` with reading from the console.

{% highlight scala %}

    val readNumber = Console.in.readLine().toInt // read 5

    val readNumberPlusReadNumber = readNumber + readNumber // 5 + 5 is 10
    val readNumberPlusReadNumberInlined = 
        Console.in.readLine().toInt + Console.in.readLine().toInt //read 5, read 5

    assert(numberPlusNumber == readNumberPlusReadNumberInlined) //true

{% endhighlight %}

We might look at this and say there is no problem (provided we always input the same numbers).
But numbers are not the problem here. In this case by applying the same copy-paste refactor,
we don't end up with the original program!

In `readNumberPlusReadNumber` we read ONCE from the console. Even though we said we want to read two numbers: 
{% highlight scala %} readNumberPlusReadNumber = readNumber + readNumber {% endhighlight %}

In `readNumberPlusReadNumberInlined` we read TWICE from the console.

The two programs are not the same anymore! The nice and intuitive meaning of `=` is lost.
We can no longer refactor easily because we have to think about the effects which generate the values, _when_
did they happen.


In this case `=` assigns only the value provided by the effect of reading from the console.
> In this sense `=` is broken, it does not work as the equals from math, the left side is not truly equal to the right side. It assigns the value, 
> but loses the effect which generated the value. This makes refactoring harder since the effect is left
> to the programmers mind and memory to manage it and keep track of.

### The fix

The good news is that we can fix `=` and make it have the meaning of equals from math.
The trick is to also keep track of the effect in the type itself, not just the value.
Our new type will contain: effect + value.


{% highlight scala %}
    class ValueFromEffect[A](a: () => A)
{% endhighlight %}

Now we can define a variable which will run an effect that will produce a value.

{% highlight scala %}
    val readNumberValue = new ValueFromEffect(() => Console.in.readLine().toInt)
{% endhighlight %}

but if we write

{% highlight scala %}

    val readNumberValueDoubled = readNumberValue + readNumberValue

{% endhighlight %}

we will get a compile error since `+` is not defined for our ValueFromEffect, but not just `+`, we don't
have any operation defined for this type, so we have to find a generic way to extract and combine these values.

{% highlight scala %}

    class ValueFromEffect[A](a : () => A) {
      def runEffectToGetValue: A = a()

      def flatMap[B](f: A => ValueFromEffect[B]): ValueFromEffect[B] =
        new ValueFromEffect[B](() => f(runEffectToGetValue).runEffectToGetValue)
    }
{% endhighlight %}
    
With the methods defined above now we can combine any number of ValueFromEffect variables.
{% highlight scala %}

    val readNumberValue = new ValueFromEffect(() => Console.in.readLine().toInt)
    
    val readNumberValueDoubled = 
        readNumberValue.flatMap(a => 
            readNumberValue.flatMap(b => 
                new ValueFromEffect(() => a + b)))
                
 {% endhighlight %}   
 
Lets try again to refactor the program with the copy-paste method, literally replacing everywhere readNumberValue with its definition

{% highlight scala %}

    val readNumberValueDoubledInlined =  
        new ValueFromEffect(() => Console.in.readLine().toInt).flatMap(a => 
            new ValueFromEffect(() => Console.in.readLine().toInt).flatMap(b => 
                new ValueFromEffect(() => a + b)))
{% endhighlight %}
 
what is left is to `runEffectToGetValue` on these programs and check our refactor did not change the meaning and they behave the same
{% highlight scala %}

    assert(readNumberValueDoubled.runEffectToGetValue == readNumberValueDoubledInlined.runEffectToGetValue) //true
 {% endhighlight %}   
 
We fixed the assignment operator!

    
Now imagine we want to write a program than prints the result of the assert 10 times.

{% highlight scala %}

        def assertToConsole(b: Boolean): Unit = println(s"assert is $b")
        val result = 
            readNumberValueDoubled.flatMap(a =>
                readNumberValueDoubled.flatMap(b => new ValueFromEffect(() => a == b)))
                    .runEffectToGetValue
        
        val printOnce = assertToConsole(result)
        List.fill(10)(printOnce) //prints "assert is X" only once!
{% endhighlight %}

Woops! We have the same problem as with the console read. Print is also an effect and we lost the effect in the type of list in this case.
The solution is to use our type which keeps track of both effect and value:

{% highlight scala %}

    def assertToConsole(b: Boolean): Unit = println(s"assert is $b")
    val result = 
        readNumberValueDoubled.flatMap(a =>
            readNumberValueDoubled.flatMap(b => new ValueFromEffect(() => a == b)))
                .runEffectToGetValue
                
    val printOnce = new ValueFromEffect(() => assertToConsole(result))
    val printTenTimes = List.fill(10)(printOnce).reduce ( (e1, e2) => e1.flatMap(_ => e2) )
    printTenTimes.runEffectToGetValue //prints "assert is X" 10 times
    
{% endhighlight %}
    
But using `runEffectToGetValue` is running the effect, this is the same as having console read or print here,
if we want to build bigger programs while still keeping the benefits of `=` we can't do this.

No matter the number and kind of effects (read/write console, disk, read sistem time) we can always refactor 
and call `runEffectToGetValue` only once.

{% highlight scala %}
object PureToImpure {

  def main(args: Array[String]): Unit =
    pureProgram.runEffectToGetValue

  def assertToConsole(b: Boolean): Unit = println(s"assert is $b")

  def pureProgram: ValueFromEffect[Unit] = {

    val result = readNumberValueDoubled.flatMap(a =>
      readNumberValueDoubled.flatMap(b =>
        new ValueFromEffect(() => a == b)))

    def printOnce(b: Boolean) = new ValueFromEffect(() => assertToConsole(b))

    val printTenTimes = result.flatMap(r =>
      List.fill(10)(printOnce(r)).reduce ( (e1, e2) => e1.flatMap(_ => e2))
    )

    printTenTimes
  }

  val readNumberValue = new ValueFromEffect(() => Console.in.readLine().toInt)
  val readNumberValueDoubled = 
    readNumberValue.flatMap(a => 
        readNumberValue.flatMap(b => 
            new ValueFromEffect(() => a + b)))
}
{% endhighlight %}

Here we have a pureProgram, where no effects run, only descriptions of them exist in ValueFromEffect.
All the descriptions are then composed together and returned as a single one: `printTenTimes`

On this we call `runEffectToGetValue` once in Main. 
> This is what is called pushing effects to the boundary of the program.  
> 
> And being able to do the copy-paste refactor without changing the behavior is called referencial transparency (or purity - due to lack of effects)
> which leads to algebraic reasoning,
> meaning our code has well defined rules and properties making it easier to refactor and compose small programs into larger programs  
