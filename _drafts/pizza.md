---
layout: post
title:  "Pizza"
date:   2022-01-12 08:00:00 -0200
categories: functional programming, scala
---
# Making invalid pizza recipes unrepresentable

Most of use like pizza. Simplistically to make one we need to first flatten some dough,
add the base sauce, add the topping and cook it. It is important to follow all these steps and
in the right order. If we don't follow these steps we get something which is not a pizaa.
We will build an API for making pizza and we will try to design it such that the clients of the API
can make pizzas even if they are not cooks - they will be forced to follow all the steps, else the code won't compile.

#Generic Pizza recipe
To make pizza we need to first flatten some dough,
add the base sauce, add the topping and cook it.
We will model the steps in an ADT.

{% highlight scala %}

    sealed trait MakePizzaStep extends Product with Serializable
    case class SetupDough(size: Int) extends MakePizzaStep
    case object AddSauce extends MakePizzaStep
    case class AddTopping(topping: String) extends MakePizzaStep
    case object Cook extends MakePizzaStep

{% endhighlight %}

After each of the steps we get an unfinished pizza,and only following all the steps we get a finished pizza. 
We model these intermediary results with another ADT

{% highlight scala %}

    sealed trait Pizza
    case class FinishedPizza(size: Int, topping: String) extends Pizza

    sealed trait UnfinishedPizza extends Pizza
    object NoPizza extends UnfinishedPizza
    case class Base(size: Int) extends UnfinishedPizza
    case class BaseWithSauce(size: Int) extends UnfinishedPizza
    case class Uncooked(size: Int, topping: String) extends UnfinishedPizza

{% endhighlight %}

To make pizza we are left to implement the function which will read the steps and make the pizza.
This method will return either a FinishedPizza, or if the steps provided are in the wrong order or incomplete
it will return a Pizza Error

{% highlight scala %}

    final case class PizzaError(description: String)

    def makePizza(steps: List[MakePizzaStep]): Either[PizzaError, FinishedPizza] = {
        val pendingPizza = steps.foldLeft(NoPizza.asRight[PizzaError].widen[Pizza]) {
            case (Right(NoPizza), SetupDough(size)) => Base(size).asRight
            case (Right(Base(size)), AddSauce) => BaseWithSauce(size).asRight
            case (Right(BaseWithSauce(size)), AddTopping(topping)) => Uncooked(size, topping).asRight
            case (Right(Uncooked(size, topping)), _: Cook.type) => FinishedPizza(size, topping).asRight
            case _ => PizzaError("bad instructions").asLeft[FinishedPizza]
            case (e: Left[_,_], _) => e
        }
    
        pendingPizza match {
          case Left(e) => e.asLeft[FinishedPizza]
          case Right(_: UnfinishedPizza) => PizzaError("bad instructions").asLeft[FinishedPizza]
          case Right(p: FinishedPizza) => p.asRight
        }
    }

{% endhighlight %}

Our API is now complete in the sense that we can make pizzas by following pizza recipes.

{% highlight scala %}

    test("make pizza") {
    
        val steps = List(SetupDough(2), AddSauce, AddTopping("mushrooms"), Cook)
    
        val mediumMushroomPizza = TypeOrder.makePizza(steps)
    
        inside (mediumMushroomPizza) {
          case Left(e) => Assertions.fail(e.description)
          case Right(pizza) => Assertions.assert(pizza == FinishedPizza(2, "mushrooms"))
        }
    }

{% endhighlight %}

But is is also very error prone, since the user of the API needs to know details about how pizza is made, else he will get a pizza error.
He needs to know to build the list with all the steps and in the right order before passing it to makepizza()
It would be best if the API would be safer to use such that the user will be guided in making valid pizzas.
Our API will provide a PizzaRecipeBuilder. It will have the responsibility of building the recipes in the right order.
We start with a definition which let's us build recipes like this:

{% highlight scala %}

    val recipe = 
      PizzaRecipeBuilder(SetupDough(2))
        .andThen(AddSauce)
        .andThen(AddTopping("mushrooms"))
        .andThen(Cook)
        .recipe

{% endhighlight %}  
{% highlight scala %}

    sealed class PizzaRecipeBuilder[A <: MakePizzaStep](head: A) { that =>
    protected val _steps: List[MakePizzaStep] = List(head)
    
        def steps: List[MakePizzaStep] = _steps.reverse
    
        def andThen[B <: MakePizzaStep](nextStep: B): PizzaRecipeBuilder[B] =
          new PizzaRecipeBuilder(nextStep) {
            override val _steps: List[MakePizzaStep] = nextStep :: that._steps
          }
    }

{% endhighlight %}

This is just the starting point since with it we can still build invalid recipes

{% highlight scala %}

    test("pizza builder  - wrong ordering") {
      val recipe = PizzaRecipeBuilder(SetupDough(2))
        //Woops! we are forgetting the Sauce
        .andThen(AddTopping("mushrooms")) 
        .andThen(Cook)
        .recipe
  
      val pizza = TypeOrder.makePizza(recipe)
  
      inside(pizza) {
        case Left(e) => Assertions.fail(e.description)
        case Right(p) => Assertions.assert(p == FinishedPizza(2, "mushrooms"))
      }
    }

{% endhighlight %}

We need to enforce the builder to only add valid next steps given it's current state.
We will use implicits and typeclasses for this. We will define a RecipeTransition[A, B] typeclass
which will be a required implicit parameter to andThen(). We will then enforce correct ordering by implementing only those RecipeTransitions which we want to allow.


{% highlight scala %}

    sealed class PizzaRecipeBuilder[A <: MakePizzaStep](firstStep: A) { that =>
      protected val _steps: List[MakePizzaStep] = List(firstStep)

      def steps: List[MakePizzaStep] = _steps.reverse

      def andThen[B <: MakePizzaStep](nextStep: B)(implicit ev: RecipeTransition[A, B]): PizzaRecipeBuilder[B] =
        new PizzaRecipeBuilder(nextStep) {
          override val _steps: List[MakePizzaStep] = nextStep :: that._steps
        }
    }

    sealed trait RecipeTransition[A <: MakePizzaStep, B <: MakePizzaStep]  

    object RecipeTransition {
      implicit val addSauceAfterDough: RecipeTransition[SetupDough, AddSauce.type ] =
        new RecipeTransition[SetupDough, AddSauce.type] {}  

      implicit val addToppingAfterSauce: RecipeTransition[AddSauce.type, AddTopping] =
        new RecipeTransition[AddSauce.type , AddTopping] {}  

      implicit val cookAfterTopping: RecipeTransition[AddTopping, Cook.type] =
        new RecipeTransition[AddTopping, Cook.type] {}
    }

{% endhighlight %}

Now our test won't compile, as it is forcing us to add the sauce

{% highlight scala %}

    test("pizza builder  - wrong ordering") {
      val recipe = PizzaRecipeBuilder(SetupDough(2))
        .andThen(AddTopping("mushrooms")) 
        // could not find implicit value for parameter ev: RecipeTransition[SetupDough,AddSauce.type]
        .andThen(Cook)
        .recipe
  
      val pizza = TypeOrder.makePizza(recipe)
  
      inside(pizza) {
        case Left(e) => Assertions.fail(e.description)
        case Right(p) => Assertions.assert(p == FinishedPizza(2, "mushrooms"))
      }
    }

{% endhighlight %}

The design up to here forces us to define the recipe in the correct order, but it still has 2 issue.
Even though the sequence might be correct, we might forget some last steps, like Cooking,
or we might forget the first steps, like setting up the Dough

{% highlight scala %}

    val uncookedPizza = PizzaRecipeBuilder(SetupDough(2))
      .andThen(AddSauce)
      .andThen(AddTopping("mushrooms"))
      .recipe

    val notEvenAMargherita= PizzaRecipeBuilder(AddSauce)
      .andThen(AddTopping("mushrooms"))
      .andThen(Cook)
      .recipe

{% endhighlight %}

To fix this we need to do a few things. First we will only allow calling recipe on a PizzaRecipeBuilder[Cook].
We can do this by defining a new TypeClass FinalStep[A] with a single implementation FinalStep[Cook] and require it on the recipe function,
but instead we will use the more suggestive Is[A, B] typeclass from Cats.

{% highlight scala %}

    import cats.evidence.===
    def recipe(implicit ev: A === Cook.type): List[MakePizzaStep] = _steps.reverse

{% endhighlight %}

Second, we can not allow starting the recipe from am intermediary step. We will put implicit parameters in the companion object
so that we can make private the construtor - we still need it to make the transition from a Pizza RecipeBuilder[A] to RecipeBuilder[B]

{% highlight scala %}

    sealed class PizzaRecipeBuilder[A <: MakePizzaStep] private(firstStep: A) { that =>
    protected val _steps: List[MakePizzaStep] = List(firstStep)
    
        def recipe(implicit ev: A === Cook.type): List[MakePizzaStep] = _steps.reverse
    
        def andThen[B <: MakePizzaStep](nextStep: B)(implicit ev: RecipeTransition[A, B]): PizzaRecipeBuilder[B] =
          new PizzaRecipeBuilder(nextStep) {
            override val _steps: List[MakePizzaStep] = nextStep :: that._steps
          }
    }
    
    object PizzaRecipeBuilder {
      def apply[A <: MakePizzaStep](a: A)(implicit ev: A === SetupDough) = new PizzaRecipeBuilder[A](a)
    }

{% endhighlight %}

Having all this, we can go ahead make makePizza private, because we will wrap it with a safe pizza method

{% highlight scala %}

    sealed class PizzaRecipeBuilder[A <: MakePizzaStep] private(firstStep: A) { that =>
    protected val _steps: List[MakePizzaStep] = List(firstStep)

    def recipe(implicit ev: A === Cook.type): PizzaRecipe = new PizzaRecipe(_steps.reverse)

    def andThen[B <: MakePizzaStep](nextStep: B)(implicit ev: RecipeTransition[A, B]): PizzaRecipeBuilder[B] =
      new PizzaRecipeBuilder(nextStep) {
        override val _steps: List[MakePizzaStep] = nextStep :: that._steps
      }
    }

    object PizzaRecipeBuilder {
      def apply[A <: MakePizzaStep](a: A)(implicit ev: A === SetupDough) = new PizzaRecipeBuilder[A](a)
    }

    def makePizzaSafe(steps: PizzaRecipe): FinishedPizza = {
        makePizza(steps.list).toOption.get //safe due to our PizzaRecipeBuilder/Recipe guarantees
    }

{% endhighlight %}

With this, the client can only make FinishedPizza(s)! no error is possible.

!! Transforming an Either to an Option and getting on it is a cheat. In the small context of makePizzaSafe
there is no type guarantee that this won't fail - but in the larger context of the API we know the user of the client can build
only safe Recipes. A type-safe solution for this would be to use Shapeless HList instead of a List and have a smarter makePizza function
using Shapeless magic. I'm not experienced in Shapeless so I will leave it as it is for now.



---

{% highlight scala %}

{% endhighlight %}

