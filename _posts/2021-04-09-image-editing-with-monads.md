---
layout: post
title:  "Image editing with Monads"
image:
    path: assets/posts/monad-image/birdie-border-and-circle.png
tags: [functional programming, scala, category-theory, monad]


---
Continuing from [image editing with Applicative](/blog/2021/02/11/image-editing-with-applicative), we will now understand Monad by editing images with it.

### Monad

A monad is composed of 2 things:
1. A function which can wrap any value `A` with the context `F`:  `pure(a: A): F[A]` (A monad is also an applicative)
2. One of the two sets of functions which are equivalent to each other (can rewrite one in term of the other)
* `flatMap(fa: F[A], f: A => F[B]): F[B]`
* map + `flatten(fa: F[F[A]]): F[A]`

Just like applicative, these functions also have to obey some laws:

Below `flatMap` is used with the enhanced syntax:

{% highlight scala %}
fa.flatMap(f: A => F[B]): F[B]
//where fa is of type F[A]
{% endhighlight %}

- left-identity
{% highlight scala %}
F.pure(x).flatMap(f) == f(x)
{% endhighlight %}
  
- right-identity
{% highlight scala %}
m.flatMap(a => F.pure(a)) == m
{% endhighlight %}
  
- associativity
{% highlight scala %}
m.flatMap(f).flatMap(g) == m.flatMap(x => f(x).flatMap(g))
{% endhighlight %}
  
They can be checked automatically with cats-laws:
  
{% highlight scala %}
checkAll("Monad laws", MonadTests(Image.imMonad).monad[Int, Int, String])
{% endhighlight scala %}

#### FlatMap
`flatMap(fa: F[A], f: A => F[B]): F[B]`

This takes a value in a context and a function `f` from a value to a value in a context and returns its result.
It seems a bit strange that `f` returns a `F[B]` not just a `B` (as the functor's map), so unlike the functor this is not
just a simple transformation of `F[A]`, it's a transformation of A into B plus a new `F` context/effect.

If applicative lets us merge effects then `flatMap` provides the ability to chain new effects having the original wrapped value as input.

#### Flatten
`flatten(fa: F[F[A]]): F[A]`

This is merging effects. The difference from applicative, these are "serial" effects `F[F[A]]`
while applicative merges parallel effects in `map2(a: F[A], b: F[B], f: (A, B) => C): F[C]`

#### FlatMap vs Flatten and Map

These are equivalent

{% highlight scala %}
def flatMap[F[_], A, B](fa: F[A])(f: A => F[B]): F[B] = flatten(map(fa, f))

def flatten[F[_], A](ffa: F[F[A]]): F[A] = flatMap(ffa)(a => a)
{% endhighlight %}

#### Monad on Images

Before and even after I implemented Monad on Images it was very unclear for a while how to do anything useful. What does it mean to have flatMap on Images ? 
Given a color image, from each color build a new image and somehow return a single image back? Well apparently yes,
the new image is what the function `f` draws on top of it, given the color at each location.

{% highlight scala %}
  implicit val imMonad: Monad[Image] = new Monad[Image] {

    override def pure[A](x: A): Image[A] = new Image[A]({
      _: Loc => x
    })

    override def flatMap[A, B](fa: Image[A])(f: A => Image[B]): Image[B] = new Image[B]({
      loc =>
        val img: Image[B] = f(fa.im(loc))
        img.im(loc)
    })

    //required for the stack-safety of some helper functions of monad which perform iterations
    @tailrec
    override def tailRecM[A, B](a: A)(f: A => Image[Either[A, B]]): Image[B] = new Image[B]({
      loc =>
        def rec(ab: Either[A, B]): B = ab match {
          case Left(a) => rec(f(a).im(loc))
          case Right(b) => b
        }

        rec(f(a).im(loc))
    })

})
{% endhighlight %}

The implementation returns a new image, which for each pixel/Location returns the color of f's Image[B] at that location,
and since f has the power to build new images given a color, it can decide each location what color it has, it can be the original input color A or ignore it and provide its own different color.

Functor lets us modify one image pixel by pixel, Applicative lets us merge 2 or more images by merging the colors for each location,
Monad allows us to draw another image on top of another image.
We can say the f function is one which given a color A draws an Image. Let's see some examples of these type of functions:

Draw a red circle on a bg Color background.
{% highlight scala %}
def redCircle(bg: Color, x: Float, y: Float, radius: Float): Image[Color] = {
    import Math.pow
    val circleProgram: Loc=> Color = { loc =>
      if (Color.aproxEq(
        (pow(loc.x - x, 2) + pow(loc.y - y, 2)).toFloat,
        pow(radius, 2).toFloat,
        300
      )) Color.Red else bg
    }

    new Image[Color](loc => circleProgram(loc))
  }
{% endhighlight %}

Draw c color stripes on a bg background.
{% highlight scala %}
  def stripes(c: Color, bg: Color): Image[Color] =
    new Image( loc =>
      if (loc.x % 10 == 0) c else bg
    )
{% endhighlight %}

Fill the top half with c color and the bottom half with bg color
{% highlight scala %}
  def topHalf(c: Color, bg: Color): Image[Color] =
    new Image( loc =>
      if (loc.y < 200) c else bg
    )
{% endhighlight %}

Add a 10px black border on a c Color background
{% highlight scala %}
  def addBlackBorder(c: Color): Image[Color] = {
    new Image[Color](loc =>
      if (loc.x <= 10 || loc.y <= 10 || loc.x >= 630 || loc.y >= 416)
        new Color(0f, 0f, 0f, c.alpha)
      else
        c
    )
  }
{% endhighlight %}
We can see these type of functions can easily be the primitive tools in an image drawing/editing program. We can draw lines, patterns, fill color, etc.
With the help of `flatMap` we can draw them one on top of another, so  it looks like Monads on Images add the drawing in layers feature.

### Examples
Draw red circe on green background, add white stripes, draw another red circle, add black border.  

{% highlight scala %}
Image.redCircle(Color.Green, 300, 200, 200)
  .flatMap(Image.stripes(Color.White, _))
  .flatMap(Image.redCircle(_, 500, 110, 200))
  .flatMap(Image.addBlackBorder)
{% endhighlight %}  

![drawing](/assets/posts/monad-image/monad-border-and-circle.png)

-----


Starting from a blue background draw a red circle but keep only the top half of the circle, the bottom is the original blue background.
{% highlight scala %}
Image.imMonad.pure(Color.Blue)
  .flatMap(bg => Image.redCircle(bg, 200, 200, 200).flatMap(circleColor => Image.topHalf(circleColor, bg)))
{% endhighlight %}  
![drawing-stripes](/assets/posts/monad-image/half-of-circle.png)

-----

Starting from a blue background draw stripes on it where the color of the stripes is the color taken fro, the bird image at the respective location.  
So the actual color of the stripes is not blue, but the color from the bird image.
{% highlight scala %}
  Image.imMonad.pure(Color.Blue)
    .flatMap(bg => bird.flatMap(birdColor => Image.stripes(birdColor, bg)))
{% endhighlight %}  
![drawing-stripes](/assets/posts/monad-image/stripes-from-bird-color.png)

-----

On the bird image, draw a red circle but only keep the bottom half,  
then over draw stripes but with the color taken from the crayons image at corresponding location and here keep only the top half,  
then over draw a red circle,  
then over add a black border.  

{% highlight scala %}
bird.flatMap(birdColor => Image.redCircle(birdColor, 300, 200, 200).flatMap(circleColor => Image.topHalf(birdColor, circleColor)))
  .flatMap(imageUpUntilNowColor => crayons.flatMap(Image.stripes(_, imageUpUntilNowColor)).flatMap(Image.topHalf(_, imageUpUntilNowColor)))
  .flatMap(imageUpUntilNowColor => Image.redCircle(imageUpUntilNowColor, 500, 110, 200))
  .flatMap(imageUpUntilNowColor => Image.addBlackBorder(imageUpUntilNowColor))
{% endhighlight %}
![drawing-on-bird](/assets/posts/monad-image/birdie-border-and-circle.png)

-----

Drawing with functional programming, this is becoming addictive fast.
We can do a lot of image editing already with [Functors](/blog/2021/01/25/images-functor), [Applicatives](/blog/2021/02/11/image-editing-with-applicative) and Monads,
but we are limited on operations on pixels at the same location:  
- functors - apply color transformation on the original pixel,
- applicative - blend two color pixels together,
- monad - draw a completely new image given the original pixel color and blend back this new image in the original one.
  
For now its impossible to move/switch pixels around for example resize/skew/mirror the image or create swirl effects. We'll try to do this in the next post.
