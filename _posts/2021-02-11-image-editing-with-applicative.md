---
layout: post
title:  "Image editing with Applicative"
date:   2021-02-11 08:30:00 -0200
image:
    path: assets/posts/applicative-image/recolor.png
tags: [functional programming, scala, category-theory, applicative, applicative functor]


---
Continuing from [image editing with Functors](/blog/2021/01/25/images-functor), we will now understand Applicative by editing images with it.

### Applicative
An applicative is composed of 2 things:

1. A function which can wrap any value `A` with the context `F`. `pure(a: A): F[A]`. So it must be that `pure` knows what the `F` context means.
2. One of the two functions which are equivalent to each other (can rewrite one in terms of the other + `pure`):
    * `map2(a: F[A], b: F[B], f: (A, B) => C): F[C]`
    * `app(f: F[A => B], a: F[A]): F[B]`
    
Below `app` is used with the enhanced syntax:

{% highlight scala %}
fab.app(a: F[A]): F[B]
//where fab is of type F[A => B]
{% endhighlight %}

This structure must obey the laws:

- identity
{% highlight scala %}
F.pure((a: A) => a).ap(fa) == fa
{% endhighlight %}

- Homomorphism
{% highlight scala %}
F.pure(f).ap(F.pure(a)) == F.pure(f(a))
{% endhighlight %}

- Interchange
{% highlight scala %}
ff.ap(F.pure(a)) == F.pure((f: A => B) => f(a)).ap(ff)
{% endhighlight %}

- Composition
{% highlight scala %}
val compose: (B => C) => (A => B) => (A => C) = _.compose
F.pure(compose).ap(fbc).ap(fab).ap(fa) == fbc.ap(fab.ap(fa))
{% endhighlight %}
  
These laws are a bit complicated, so again like Functors we will check them with Cats laws. The tests are more fine 
grained than only these 4 laws so if some fail we will get a better idea what and where to fix.
{% highlight scala %}
checkAll("Applicative laws", ApplicativeTests(Image.imApplicative).applicative[Int, Int, String])
{% endhighlight %}


#### Map2
{% highlight scala %}
map2(a: F[A], b: F[B], f: (A, B) => C): F[C]`
{% endhighlight %}

This says it can merge two contexts. The `f` function knows how to merge A and B into a new value C,
but `map2` knows (just like `pure`) about what the `F` context means, so it actually knows to merge both contexts together.
We can replace the word "context" with "effect":  map2 knows how to merge two effects.

#### Apply
{% highlight scala %}
app(f: F[A => B], a: F[A]): F[B]
{% endhighlight %}

This is more tricky to understand intuitively but given a function/program wrapped in the context/effect `F`,
we can run the program with the value in `a: F[A]`.
Not to be confused with the functor's `map(a: F[A], f: A => B): F[B]` - there is an extra `F` over `f` in apply.

Because `apply` also gets as input two `F`s and returns only one it means that it also knows how to merge these `F`s (just like `map2`)

#### Map2 vs Apply
So what is the difference? Formally none because we can write one in terms of the other + pure

{% highlight scala %}
def map2[F[_], A, B, C](fa: F[A], fb: F[B], f: (A, B) => C): F[C] = {
  val one = ap(pure(f curried))(fa)
  ap(one)(fb)
}

def apply[A, B](ff: F[A => B])(fa: F[A]): F[B] =
  map2(ff, fa)((f, a) => f(a))

{% endhighlight %}

So it's clear that both `map2` and `apply` know how to merge F contexts/effects, but what about the difference in signatures?

`ff: F[A => B]` from `apply` is the partial application of `f: (A, B) => C` from `map2` with `a: F[A]`.
It kinda holds a `F[A]` inside. More precisely it's a program which ran with input A will produce a F[B].
We'll see this below on images.

#### Applicative is also a Functor
The complete name is: [applicative functor](http://www.staff.city.ac.uk/~ross/papers/Applicative.pdf).
{% highlight scala %}
def map[A, B](fa: F[A])(f: A => B): F[B] =
  ap(pure(f))(fa)
{% endhighlight %}

But functor is not an applicative, functor does not have `pure` so it does not know as much about what `F` means.

#### Applicative on images
{% highlight scala %}
implicit val imApplicative: Applicative[Image] = new Applicative[Image] {
    override def pure[A](x: A): Image[A] = new Image[A]({
      _: Loc => a
    })

    override def ap[A, B](ff: Image[A => B])(fa: Image[A]): Image[B] = {
      new Image[B]( loc => 
        ff.im(loc)(fa.im(loc))
      )
    }
}
{% endhighlight %}

[bird]:https://github.com/adrian-salajan/dimages/blob/master/src/main/resources/bird.png?raw=true
[cy]:https://github.com/adrian-salajan/dimages/blob/master/src/main/resources/crayons.png?raw=true
[max]:https://github.com/adrian-salajan/dimages/blob/master/png/applicative/max.png?raw=true
[sw]:https://github.com/adrian-salajan/dimages/blob/master/png/applicative/seeThroughWhite.png?raw=true
[disolve]:https://github.com/adrian-salajan/dimages/blob/master/png/applicative/disolve.png?raw=true


Given F is an Image it means we can combine any 2 images, pixel by pixel. Of course, if we can combine 2 images we can also combine any N images.

#### Original image A:

![original image A][bird]

#### Original image B:

![original image B][cy]

#### Max brightness between A and B

{% highlight scala %}

def max(a: Image[Color], b: Image[Color]): Image[Color] =  
  a.map2(b) {  
    case (a, b) => if (a.brightness > b.brightness) a else b  
  }

{% endhighlight %}

![max][max]

#### See through white

{% highlight scala %}

def overlapIf(imga: Image[Color], imgb: Image[Color], f: Color => Boolean): Image[Color] = {
  val effect: Color => Color => Color = a => b => if (f(b)) a else b
  val ap1 = imApplicative.ap(imApplicative.pure(effect))(imga)
  val ap2 = imApplicative.ap(ap1)(imgb)
  ap2
}
overlapIf(bird, crayons,  c => c.isWhiteish)

{% endhighlight %}

![sw][sw]

#### Disolve (creates a new image randomly taking color from A or B)

{% highlight scala %}
overlapIf(bird, crayons,  _ => Math.random() > 0.5)
{% endhighlight %}

![disolve][disolve]

#### Recolor  

{% highlight scala %}
a.map2(b) {
  case (a, b) =>
    Color(a.brightness * b.red, a.brightness * b.green, a.brightness * b.blue)
}
{% endhighlight %}
![recolor](/assets/posts/applicative-image/recolor.png)

### Getting more intuition on Map2 and Apply

We define a program in our F (Image), which will generate a checkers-like pattern.

{% highlight scala %}

    def checkerPattern: Image[Color => Color] = {
      new Image[Color => Color](
        loc => c => loc match {
          case Loc(a, b) =>
            if (a % 10 < 5 && b % 10 < 5) Color.White
            else if (a % 10 >= 5 && b % 10 >= 5) Color.Black
            else c
        }
      )
    }

{% endhighlight %}

We will run this program giving it as input the original bird image, and we get
{% highlight scala %}
ap(checkerPattern)(bird)
{% endhighlight %}

![checkers-bird](/assets/posts/applicative-image/colorifyBird3.png)

Now let's create the same result with map2.

{% highlight scala %}
map2(bird, checkerPattern)((a, b) => b(a))
{% endhighlight %}

![checkers-bird](/assets/posts/applicative-image/colorifyBirdPlusNoBird3.png)

I'm going to repeat myself because this is awesome:  
`ff: F[A => B]` from `apply` is the partial application of `f: (A, B) => C` from `map2` with `a: F[A]`,
**it kinda holds a `F[A]` inside**. We can even extract this core image from our checkerPattern program in order to see it by giving it the transparent color:

{% highlight scala %}
checkerPattern.map(c => c(Color.Clear))
//OR
ap(checkerPattern)(pure(Color.Clear))
{% endhighlight %}

![checkers](/assets/posts/applicative-image/checker.png)

And one more fun example, combined with the bird image:

{% highlight scala %}

    def psychedelics: Image[Color => Color] = {
      new Image[Color => Color](
        loc => c => loc match {
          case Loc(a, b) => Color(
            (1f * Math.sin(a / 20) + b / 300).toFloat,
            c.green,
            (1f * Math.cos(b / 40) + a / 150).toFloat,
          )
        }
      )
    }

    ap(psychedelics)(bird)

{% endhighlight %}

![checkers](/assets/posts/applicative-image/psychedelicsBird.png)

And the core image embedded in the `F[A => B]`

![checkers](/assets/posts/applicative-image/psychedelics.png)

In the next post of this series we will see new effects done with the help of other structures from category theory, maybe monad or contravariant functor.

