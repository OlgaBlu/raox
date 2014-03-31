package ru.bmstu.rk9.rdo.generator

import java.util.List
import java.util.HashMap

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet

import org.eclipse.xtext.generator.IFileSystemAccess

import static extension org.eclipse.xtext.xbase.lib.IteratorExtensions.*

import static extension ru.bmstu.rk9.rdo.generator.RDONaming.*
import static extension ru.bmstu.rk9.rdo.customizations.RDOQualifiedNameProvider.*
import static extension ru.bmstu.rk9.rdo.generator.RDOExpressionCompiler.*
import static extension ru.bmstu.rk9.rdo.generator.RDOStatementCompiler.*

import ru.bmstu.rk9.rdo.customizations.IMultipleResourceGenerator
import ru.bmstu.rk9.rdo.customizations.SMRSelectDialog

import ru.bmstu.rk9.rdo.rdo.RDOModel

import ru.bmstu.rk9.rdo.rdo.ResourceType
import ru.bmstu.rk9.rdo.rdo.ResourceTypeParameter
import ru.bmstu.rk9.rdo.rdo.RDORTPParameterType
import ru.bmstu.rk9.rdo.rdo.RDORTPParameterBasic
import ru.bmstu.rk9.rdo.rdo.RDORTPParameterString
import ru.bmstu.rk9.rdo.rdo.RDOEnum

import ru.bmstu.rk9.rdo.rdo.ResourceDeclaration

import ru.bmstu.rk9.rdo.rdo.ConstantDeclaration

import ru.bmstu.rk9.rdo.rdo.Function
import ru.bmstu.rk9.rdo.rdo.FunctionParameter
import ru.bmstu.rk9.rdo.rdo.FunctionTable
import ru.bmstu.rk9.rdo.rdo.FunctionAlgorithmic
import ru.bmstu.rk9.rdo.rdo.FunctionList

import ru.bmstu.rk9.rdo.rdo.PatternParameter
import ru.bmstu.rk9.rdo.rdo.Event

import ru.bmstu.rk9.rdo.rdo.SimulationRun


class RDOGenerator implements IMultipleResourceGenerator
{
	override void doGenerate(Resource resource, IFileSystemAccess fsa)
	{}

	override void doGenerate(ResourceSet resources, IFileSystemAccess fsa)
	{
		//===== rdo_lib ====================================================================
		fsa.generateFile("rdo_lib/Simulator.java",                compileLibSimulator    ())
		fsa.generateFile("rdo_lib/Event.java",                    compileEvent           ())
		fsa.generateFile("rdo_lib/PermanentResourceManager.java", compilePermanentManager())
		fsa.generateFile("rdo_lib/TemporaryResourceManager.java", compileTemporaryManager())
		//==================================================================================

		val declarationList = new java.util.ArrayList<ResourceDeclaration>();
		for (resource : resources.resources)
			declarationList.addAll(resource.allContents.filter(typeof(ResourceDeclaration)).toIterable)

		val simulationList = new java.util.ArrayList<SimulationRun>();
		for (resource : resources.resources)
			simulationList.addAll(resource.allContents.filter(typeof(SimulationRun)).toIterable)

		var Resource resWithSMR = null
		if (simulationList.size > 1)
		{
			resWithSMR = simulationList.get(0).eResource

			val options = new HashMap<String, Resource>()

			for (s : simulationList)
				options.put(s.eResource.URI.lastSegment, s.eResource)

			resWithSMR = options.get(options.keySet.toList.get(SMRSelectDialog.invoke(options.keySet.toList)))
		}

		for (resource : resources.resources)
			if (resource.contents.head != null)
			{
				val filename = (resource.contents.head as RDOModel).filenameFromURI

				for (e : resource.allContents.toIterable.filter(typeof(ResourceType)))
					fsa.generateFile(filename + "/" + e.name + ".java", e.compileResourceType(filename,
						declarationList.filter[r | r.reference.fullyQualifiedName == e.fullyQualifiedName]))

				for (e : resource.allContents.toIterable.filter(typeof(Function)))
					fsa.generateFile(filename + "/" + e.name + ".java", e.compileFunction(filename))

				for (e : resource.allContents.toIterable.filter(typeof(Event)))
					fsa.generateFile(filename + "/" + e.name + ".java", e.compileEvent(filename))
			}

		fsa.generateFile("rdo_model/Constants.java", compileConstants(resources))

		fsa.generateFile("rdo_model/MainClass.java", compileMain(resources, resWithSMR))
	}

	def compileMain(ResourceSet rs, Resource smr)
	{
		'''
		package rdo_model;

		public class MainClass
		{
			public static void main(String[] args)
			{
				long startTime = System.currentTimeMillis();

				System.out.println(" === RDO-Simulator ===\n");
				System.out.println("   Project «RDONaming.getProjectName(rs.resources.get(0).URI)»");
				System.out.println("   Source files are «rs.resources.map[r | r.contents.head.nameGeneric].toString»\n");

				«IF smr != null»// SMR«
				FOR c :smr.allContents.filter(typeof(SimulationRun)).head.commands»
					«c.compileStatement»
				«ENDFOR»
				«ENDIF»

				System.out.println("\n   Started model");

				rdo_lib.Simulator.run();

				System.out.println("\n   Finished model in " + String.valueOf((System.currentTimeMillis() - startTime)/1000.0) + "s");

			}
		}
		'''
	}

	def compileConstants(ResourceSet rs)
	{
		'''
		package rdo_model;

		@SuppressWarnings("all")

		public class Constants
		{
			«FOR rl : rs.resources»«IF rl.contents.head.eAllContents.filter(typeof(ConstantDeclaration)).size > 0»
				public static class Constants_«rl.contents.head.nameGeneric»
				{
					«FOR r : rl.contents.head.eAllContents.filter(typeof(ConstantDeclaration)).toIterable»
						public static final «r.type.compileType» «r.name» = «r.value.compileExpression»;
					«ENDFOR»
				}

			«ENDIF»«ENDFOR»
			«FOR rl : rs.resources»«IF rl.contents.head.eAllContents.filter(typeof(ConstantDeclaration)).size > 0»
				public static final Constants_«rl.contents.head.nameGeneric» «rl.contents.head.nameGeneric» = new Constants_«rl.contents.head.nameGeneric»();
			«ENDIF»«ENDFOR»
		}
		'''
	}
	
	def withFirstUpper(String s)
	{
		return Character.toUpperCase(s.charAt(0)) + s.substring(1)
	}

	def compileResourceType(ResourceType rtp, String filename, Iterable<ResourceDeclaration> instances)
	{
		'''
		package «filename»;

		public class «rtp.name»
		{
			private final static rdo_lib.«rtp.type.literal.withFirstUpper
				»ResourceManager<MSA> manager = new rdo_lib.«rtp.type.literal.withFirstUpper»ResourceManager<MSA>();

			public static rdo_lib.«rtp.type.literal.withFirstUpper»ResourceManager<MSA> getManager()
			{
				return manager;
			}

			«IF rtp.eAllContents.filter(typeof(RDOEnum)).toList.size > 0»// ENUMS«ENDIF»
			«FOR e : rtp.eAllContents.toIterable.filter(typeof(RDOEnum))»
				enum «RDONaming.getEnumParentName(e, false)»_enum
				{
					«e.makeEnumBody»
				}

			«ENDFOR»
			«FOR parameter : rtp.parameters»
				public «parameter.type.compileType» «parameter.name»«parameter.type.getDefault»;
			«ENDFOR»

			public «rtp.name»(«rtp.parameters.compileResourceTypeParameters»)
			{
				«FOR parameter : rtp.parameters»
					if («parameter.name» != null)
						this.«parameter.name» = «parameter.name»;
				«ENDFOR»
			}
			«FOR r : instances»

				public static final «rtp.name» «r.name» = new «rtp.name»(«
					if (r.parameters != null) r.parameters.compileExpression else ""»);
				{
					«rtp.name».getManager().addResource("«r.name»", «r.name»);
				}
			«ENDFOR»			
		}
		'''
	}

	def makeEnumBody(RDOEnum e)
	{
		var flag = false
		var body = ""

		for (i : e.enums)
		{
			if (flag)
				body = body + ", "
			body = body + i.name
			flag = true
		}
		return body
	}

	def compileFunction(Function fun, String filename)
	{
		'''
		package «filename»;
		
		public class «fun.name»
		'''
		 +
		switch fun.type
		{
			FunctionAlgorithmic:
			'''
			{
				
			}
			'''
			FunctionTable:
			'''
			{
				
			}
			'''
			FunctionList:
			'''
			{
				
			}
			'''
		}
	}

	def compileEvent(Event evn, String filename)
	{
		'''
		package «filename»;

		public class «evn.name» extends rdo_lib.Event
		{
			@Override
			public String getName()
			{
				return "«evn.fullyQualifiedName»";
			}

			«FOR parameter : evn.parameters»
				private «parameter.type.compileType» «parameter.name»«parameter.type.getDefault»;
			«ENDFOR»

			public «evn.name»(«evn.parameters.compilePatternParameters»)
			{
				«FOR parameter : evn.parameters»
					if («parameter.name» != null)
						this.«parameter.name» = «parameter.name»;
				«ENDFOR»
			}

			@Override
			public void calculateEvent()
			{
				// retrieve/create relevant resources
				«FOR r : evn.relevantresources»
					«IF r.type instanceof ResourceType»
						«(r.type as ResourceType).fullyQualifiedName» «
							r.name» = new «(r.type as ResourceType).fullyQualifiedName»(«
								(r.type as ResourceType).parameters.size.compileAllDefault»);
					«ELSE»
						«(r.type as ResourceDeclaration).reference.fullyQualifiedName» «r.name» = «
							(r.type as ResourceDeclaration).reference.fullyQualifiedName».«
								(r.type as ResourceDeclaration).name»;
					«ENDIF»
				«ENDFOR»

				«FOR e : evn.algorithms»
					«RDOStatementCompiler.compileStatement(e)»

				«ENDFOR»
				«IF evn.relevantresources.map[t | t.type].filter(typeof(ResourceType)).size > 0»
					// add created resources
					«FOR r : evn.relevantresources»
						«IF r.type instanceof ResourceType»
							«(r.type as ResourceType).fullyQualifiedName».getManager().addResource(«r.name»);
						«ENDIF»
					«ENDFOR»
				«ENDIF»
			}
		}
		'''
	}

	def static String getDefault(RDORTPParameterType parameter)
	{
		switch parameter
		{
			RDORTPParameterBasic:
				return if (parameter.^default != null) " = " + RDOExpressionCompiler.compileExpression(parameter.^default) else ""
			RDORTPParameterString:
				return if (parameter.^default != null) ' = "' + parameter.^default + '"' else ""
			default:
				return ""
		}
	}

	def static compileResourceTypeParameters(List<ResourceTypeParameter> parameters)
	{
		'''«IF parameters.size > 0»«parameters.get(0).type.compileType» «
			parameters.get(0).name»«
			FOR parameter : parameters.subList(1, parameters.size)», «
				parameter.type.compileType» «
				parameter.name»«
			ENDFOR»«
		ENDIF»'''
	}

	def static compilePatternParameters(List<PatternParameter> parameters)
	{
		'''«IF parameters.size > 0»«parameters.get(0).type.compileType» «
			parameters.get(0).name»«
			FOR parameter : parameters.subList(1, parameters.size)», «
				parameter.type.compileType» «
				parameter.name»«
			ENDFOR»«
		ENDIF»'''
	}

	def static compileFunctionParameters(List<FunctionParameter> parameters)
	{
		'''«IF parameters.size > 0»«parameters.get(0).type.compileType» «
			parameters.get(0).name»«
			FOR parameter : parameters.subList(1, parameters.size)», «
				parameter.type.compileType» «
				parameter.name»«
			ENDFOR»«
		ENDIF»'''
	}

	def compilePermanentManager()
	{
		'''
		package rdo_lib;

		public class PermanentResourceManager<T>
		{
			protected java.util.Map<String, T> resources = new java.util.HashMap<String, T>();

			public void addResource(String name, T res)
			{
				resources.put(name, res);
			}

			public T getResource(String name)
			{
				return resources.get(name);
			}
			
			public java.util.Collection<T> getAll()
			{
				return resources.values();
			}
		}
		'''
	}
	
	def compileTemporaryManager()
	{
		'''
		package rdo_lib;

		public class TemporaryResourceManager<T> extends PermanentResourceManager<T>
		{
			private java.util.Map<T, Integer> temporary = new java.util.HashMap<T, Integer>();

			private java.util.Queue<Integer> vacantList = new java.util.LinkedList<Integer>();
			private int currentLast = 0;

			public void addResource(T res)
			{
				if (temporary.containsKey(res))
					return;

				int number;
				if (vacantList.size() > 0)
					number = vacantList.poll();
				else
					number = currentLast++;

				temporary.put(res, number);
			}

			public void eraseResource(T res)
			{
				vacantList.add(temporary.get(res));
				temporary.remove(res);
			}

			@Override
			public java.util.Collection<T> getAll()
			{
				java.util.Collection<T> all = resources.values();
				all.addAll(temporary.keySet());
				return all;
			}

			public java.util.Collection<T> getTemporary()
			{
				return temporary.keySet();
			}

		}
		'''
	}

	def compileLibSimulator()
	{
		'''
		package rdo_lib;

		import java.util.PriorityQueue;
		import java.util.Comparator;

		import rdo_lib.Event;

		public abstract class Simulator
		{
			private static double time = 0;

			public static double getTime()
			{
				return time;
			}

			private static class PlannedEvent
			{
				private Event event;
				private double plannedFor;

				public Event getEvent()
				{
					return event;
				}

				public double getTimePlanned()
				{
					return plannedFor;
				}

				public PlannedEvent(Event event, double time)
				{
					this.event = event;
					this.plannedFor = time;
				}
			}

			private static Comparator<PlannedEvent> comparator = new Comparator<PlannedEvent>()
			{
				@Override
				public int compare(PlannedEvent x, PlannedEvent y)
				{
					if (x.getTimePlanned() < y.getTimePlanned()) return -1;
					if (x.getTimePlanned() > y.getTimePlanned()) return  1;
					return 0;
				}
			};

			private static PriorityQueue<PlannedEvent> eventList = new PriorityQueue<PlannedEvent>(1, comparator);

			public static void pushEvent(Event event, double time)
			{
				eventList.add(new PlannedEvent(event, time));
			}

			private static PlannedEvent popEvent()
			{
				return eventList.remove();
			}

			public static void run()
			{
				while(eventList.size() > 0)
				{
					PlannedEvent current = popEvent();

					time = current.getTimePlanned();
					System.out.println("      " + String.valueOf(time) + ":	'" + current.getEvent().getName() + "' happens");

					current.getEvent().calculateEvent();
				}
			}
		}
		'''
	}

	def compileEvent()
	{
		'''
		package rdo_lib;

		public abstract class Event
		{
			public abstract String getName();
			public abstract void calculateEvent();
		}
		'''
	}
}
