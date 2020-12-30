---
layout: post
title:  "Equality in Scala "
categories: scala
---

In Scala 2 the == operator is used for checking by value equality,
in contrast with Java where .equals() is best practice.
Also in contrast to Java, == is safe to be used on null values.

{% highlight scala %}

    val a: String = "foo"  
    val b: String = null
    
    a == b //false (does not throw Exception)
{% endhighlight %}

This is because == forwards to .equals(), but right before it
a null-check is performed.

We can see this on AnyRefs.equals() scaladoc:  
> The expression `x == that` is equivalent to `if (x eq null) that eq null else x.equals(that)`.

Here we see the .eq() which tests equality by reference, which is very rarely needed, specially in FP.

This makes usage of .equals() a bad practice in Scala since it can throw exception when the left part is null. Always use == instead of equals() in Scala.

### Collection equality

== for collections means:
 - they are of the same collection type (Seq vs Set vs Map)
 - they contain the same elements (as defined by the == on the element type)
 - for sequences elements are in the same order  

{% highlight scala %}

    List(1, 2, 3) == Vector(1, 2, 3) // true  
    List(1, 2, 3) == Set(1, 2, 3) // false  
    Map(1 -> "a", "2" -> "b") == Map(1 -> "a", "2" -> "b") //true  
    List[Double](1.0, 2.0, 3.0) == Vector[Int](1, 2, 3) //true  

{% endhighlight %}


### Imperfections of ==

#### 1. Doesn't work on Arrays
Never use == on arrays, they do not behave like collections when comparing!
I still get burned by this and it's what motivated this post.

{% highlight scala %}
Array(1, 2, 3) == Array(1, 2, 3) //false
{% endhighlight %}


The solution here is to use Array.sameElements

{% highlight scala %}
    Array(1, 2, 3).sameElements(Array(1, 2, 3)) //true
{% endhighlight %}
But we humans always make errors so best to block usage of == with [Wartremover](https://www.wartremover.org/):


```
//in plugins.sbt 
addSbtPlugin("org.wartremover" % "sbt-wartremover" % "2.4.13")

//in build.sbt 
 wartremoverErrors += Wart.ArrayEquals
 ```

This will throw compilation errors when comparing arrays with ==

```
[error] [wartremover:ArrayEquals] == is disabled, use sameElements instead  
[error]     println(Array(1, 2, 3) == Array(1, 2, 3))
```


#### 2. Allows comparing different types
Because == is defined on AnyRef it can compare any two refs, regardless the type.
This is a scenario that will always evaluate to false, it is very error prone so the compiler should not even let us write this.

{% highlight scala %}
    5 == "5" //always false
{% endhighlight %}

[Cats](https://typelevel.org/cats/) defines triple equals, which does not allow comparing different types.

{% highlight scala %}
    import cats.implicits._
    5 === "5" //does not compile
{% endhighlight %}

This won't work out of the box for arrays. We have to provide an Eq instance for them:

{% highlight scala %}
    implicit def forArray[A: Eq]: Eq[Array[A]] =
        Eq.instance[Array[A]](_.sameElements(_))
{% endhighlight %}

Having all this we can go ahead and block usage of == altogether

```
    //in build.sbt 
     wartremoverErrors ++= Seq(Wart.Equals, Wart.ArrayEquals)
 ```






